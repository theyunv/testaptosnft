/// 我的第一个 NFT 模块
/// 这是一个基于 Aptos 区块链的 NFT 合约，用于创建和管理 NFT 集合和代币
module my_first_nft::my_first_nft {
    // 标准库导入
    use std::option;          // 选项类型，用于处理可选值
    use std::signer;          // 签名者类型，用于账户操作
    use std::string;          // 字符串类型
    use std::vector;          // 向量类型，用于动态数组
    use aptos_std::string_utils;  // 字符串工具函数
    use aptos_framework::event;   // 事件系统
    use aptos_framework::object;  // 对象系统
    use aptos_framework::object::Object;  // 对象类型

    // NFT 相关模块导入
    use aptos_token_objects::collection;  // 集合（Collection）功能
    use aptos_token_objects::royalty;     // 版税功能
    use aptos_token_objects::token;       // 代币（Token）功能
    use aptos_token_objects::token::Token; // 代币类型

    // ========== 常量定义 ==========
    
    /// 资源账户种子，用于创建资源账户
    const ResourceAccountSeed: vector<u8> = b"mfers";

    /// 集合描述信息
    const CollectionDescription: vector<u8> = b"mfers are generated entirely from hand drawings by sartoshi. this project is in the public domain; feel free to use mfers any way you want.";

    /// 集合名称
    const CollectionName: vector<u8> = b"mfers";

    /// 集合的 URI（统一资源标识符），指向集合的元数据
    const CollectionURI: vector<u8> = b"ipfs://QmWmgfYhDWjzVheQyV2TnpVXYnKR25oLWCB2i9JeBxsJbz";

    /// 代币的基础 URI，用于构建每个 NFT 的完整 URI
    const TokenURI: vector<u8> = b"ipfs://bafybeiearr64ic2e7z5ypgdpu2waasqdrslhzjjm65hrsui2scqanau3ya/";

    /// 代币名称前缀，例如 "mfer #1", "mfer #2" 等
    const TokenPrefix: vector<u8> = b"mfer #";

    // ========== 错误码定义 ==========
    
    /// 错误码：调用者不是 NFT 的所有者
    const ERROR_NOWNER: u64 = 1;

    /// 错误码：用户未注册
    const ERROR_NOT_REGISTERED: u64 = 2;

    /// 错误码：用户已注册
    const ERROR_ALREADY_REGISTERED: u64 = 3;

    /// 错误码：抽奖活动不存在
    const ERROR_LOTTERY_NOT_EXISTS: u64 = 4;

    /// 错误码：用户不是抽奖活动的参与者
    const ERROR_NOT_PARTICIPANT: u64 = 5;

    /// 错误码：用户未中奖
    const ERROR_NOT_WINNER: u64 = 6;

    /// 错误码：抽奖活动还未开始抽奖
    const ERROR_LOTTERY_NOT_STARTED: u64 = 7;

    /// 错误码：没有足够的 NFT 奖励
    const ERROR_INSUFFICIENT_REWARDS: u64 = 8;

    /// 错误码：只有抽奖活动管理员可以操作
    const ERROR_NOT_LOTTERY_ADMIN: u64 = 9;

    // ========== 结构体定义 ==========
    
    /// 用户账户结构体
    /// 记录参与抽奖的用户信息
    struct UserAccount has key {
        user_address: address,  // 用户地址
        is_registered: bool,    // 是否已注册
        join_time: u64          // 加入时间戳
    }

    /// 用户抽奖记录结构体
    /// 记录用户在特定抽奖活动中的参与信息
    struct UserLotteryRecord has store {
        user_address: address,  // 用户地址
        is_winner: bool,        // 是否中奖
        reward_nft_id: option::Option<address>  // 奖励 NFT 的 ID（如果中奖）
    }

    /// 抽奖活动结构体
    /// 管理单个抽奖活动的所有信息
    struct LotteryActivity has key {
        activity_id: u64,                        // 抽奖活动 ID
        admin: address,                          // 活动管理员
        title: string::String,                   // 活动标题
        description: string::String,             // 活动描述
        total_winners: u64,                      // 中奖人数
        current_winners: u64,                    // 当前已确定的中奖人数
        participants: vector<address>,           // 参与者列表
        winners: vector<address>,                // 中奖者列表
        winner_records: vector<UserLotteryRecord>, // 中奖记录列表
        reward_nft_ids: vector<address>,         // 奖励 NFT ID 列表
        lottery_started: bool,                   // 抽奖是否已开始
        created_time: u64                        // 创建时间戳
    }

    /// 全局抽奖管理器结构体
    /// 用于管理所有抽奖活动
    struct LotteryManager has key {
        next_activity_id: u64,                   // 下一个活动 ID
        activities: vector<u64>,                 // 所有活动 ID 列表
        user_activities: vector<u64>             // 用户参与的活动 ID 列表
    }

    /// 签名者能力存储结构体
    /// 用于存储集合创建者的扩展引用，允许后续扩展集合功能
    struct SignerCapabilityStore has key {
        extend_ref: object::ExtendRef  // 扩展引用，用于生成签名者以扩展对象
    }

    /// 集合引用存储结构体
    /// 存储集合对象和可变引用，用于后续对集合进行操作
    struct CollectionRefsStore has key {
        collection_object: Object<collection::Collection>,  // 集合对象
        mutator_ref: collection::MutatorRef                 // 集合可变引用，用于修改集合属性
    }

    /// 代币引用存储结构体
    /// 存储代币的各种引用，用于后续对代币进行操作（修改、销毁、转移等）
    struct TokenRefsStore has key {
        mutator_ref: token::MutatorRef,                    // 代币可变引用，用于修改代币属性
        burn_ref: token::BurnRef,                          // 销毁引用，用于销毁代币
        extend_ref: object::ExtendRef,                     // 扩展引用，用于扩展代币功能
        transfer_ref: option::Option<object::TransferRef>  // 转移引用（可选），用于转移代币所有权
    }

    // ========== 事件定义 ==========
    
    /// 铸造事件
    /// 当新的 NFT 被铸造时触发，记录所有者和代币 ID
    #[event]
    struct MintEvent has drop, store {
        owner: address,    // NFT 所有者的地址
        token_id: address  // 被铸造的 NFT 的 ID（对象地址）
    }

    /// 销毁事件
    /// 当 NFT 被销毁时触发，记录所有者和代币 ID
    #[event]
    struct BurnEvent has drop, store {
        owner: address,    // NFT 所有者的地址
        token_id: address  // 被销毁的 NFT 的 ID（对象地址）
    }

    /// 用户注册事件
    /// 当新用户注册时触发
    #[event]
    struct UserRegisteredEvent has drop, store {
        user_address: address  // 注册的用户地址
    }

    /// 用户加入抽奖活动事件
    /// 当用户参与抽奖活动时触发
    #[event]
    struct UserJoinedLotteryEvent has drop, store {
        user_address: address,   // 加入的用户地址
        activity_id: u64         // 抽奖活动 ID
    }

    /// 抽奖活动创建事件
    /// 当创建新抽奖活动时触发
    #[event]
    struct LotteryCreatedEvent has drop, store {
        activity_id: u64,        // 活动 ID
        admin: address,          // 管理员地址
        total_winners: u64       // 中奖人数
    }

    /// 抽奖开始事件
    /// 当抽奖活动开始时触发
    #[event]
    struct LotteryStartedEvent has drop, store {
        activity_id: u64,        // 活动 ID
        winners: vector<address> // 中奖者地址列表
    }

    /// 中奖 NFT 领取事件
    /// 当中奖用户领取 NFT 时触发
    #[event]
    struct WinnerClaimedRewardEvent has drop, store {
        user_address: address,   // 用户地址
        activity_id: u64,        // 活动 ID
        nft_id: address          // 领取的 NFT ID
    }

    /// ========== 用户管理函数 ==========

    /// 注册用户账户
    /// 允许新用户注册参与抽奖
    /// 
    /// 参数:
    /// - user: 要注册的用户签名者
    entry public fun register_user(user: &signer) {
        let user_addr = signer::address_of(user);
        
        // 检查用户是否已注册
        assert!(!exists<UserAccount>(user_addr), ERROR_ALREADY_REGISTERED);
        
        // 创建新用户账户
        move_to(user, UserAccount {
            user_address: user_addr,
            is_registered: true,
            join_time: 0  // 实际应该用时间戳，这里简化
        });
        
        // 触发用户注册事件
        event::emit(UserRegisteredEvent {
            user_address: user_addr
        });
    }

    /// ========== 抽奖活动管理函数 ==========

    /// 创建新的抽奖活动
    /// 只有 NFT 集合管理员可以创建抽奖活动
    /// 
    /// 参数:
    /// - admin: 活动管理员签名者
    /// - title: 活动标题
    /// - description: 活动描述
    /// - total_winners: 中奖人数
    entry public fun create_lottery_activity(
        admin: &signer,
        title: string::String,
        description: string::String,
        total_winners: u64
    ) {
        let admin_addr = signer::address_of(admin);
        
        if (!exists<LotteryManager>(admin_addr)) {
            move_to(admin, LotteryManager {
                next_activity_id: 1,
                activities: vector::empty(),
                user_activities: vector::empty()
            });
        };
        
        let manager = borrow_global_mut<LotteryManager>(admin_addr);
        let activity_id = manager.next_activity_id;
        
        // 创建新活动
        let activity = LotteryActivity {
            activity_id,
            admin: admin_addr,
            title,
            description,
            total_winners,
            current_winners: 0,
            participants: vector::empty(),
            winners: vector::empty(),
            winner_records: vector::empty(),
            reward_nft_ids: vector::empty(),
            lottery_started: false,
            created_time: 0
        };
        
        // 将活动存储在管理器的账户下
        move_to(admin, activity);
        
        // 更新管理器信息
        vector::push_back(&mut manager.activities, activity_id);
        manager.next_activity_id = activity_id + 1;
        
        // 触发活动创建事件
        event::emit(LotteryCreatedEvent {
            activity_id,
            admin: admin_addr,
            total_winners
        });
    }

    /// 用户加入抽奖活动
    /// 
    /// 参数:
    /// - user_addr: 要加入活动的用户地址
    /// - admin: 活动管理员地址
    /// - activity_id: 要加入的活动 ID
    entry public fun join_lottery_activity(
        admin: &signer,
        user_addr: address,
        activity_id: u64
    ) { 
        let admin_addr = signer::address_of(admin);
        // 获取抽奖活动
        assert!(exists<LotteryActivity>(admin_addr), ERROR_LOTTERY_NOT_EXISTS);
        let activity = borrow_global_mut<LotteryActivity>(admin_addr);
        
        // 验证活动 ID 匹配
        assert!(activity.activity_id == activity_id, ERROR_LOTTERY_NOT_EXISTS);
        
        // 验证抽奖还未开始
        assert!(!activity.lottery_started, ERROR_LOTTERY_NOT_STARTED);
        
        // 添加参与者
        vector::push_back(&mut activity.participants, user_addr);
        
        // 触发用户加入事件
        event::emit(UserJoinedLotteryEvent {
            user_address: user_addr,
            activity_id
        });
    }

    /// ========== 抽奖执行函数 ==========

    /// 启动抽奖 - 从参与者中随机选出中奖者
    /// 
    /// 参数:
    /// - admin: 活动管理员签名者
    /// - activity_id: 要启动的活动 ID
    entry public fun start_lottery(admin: &signer, activity_id: u64) {
        let admin_addr = signer::address_of(admin);
        
        // 获取抽奖活动
        assert!(exists<LotteryActivity>(admin_addr), ERROR_LOTTERY_NOT_EXISTS);
        let activity = borrow_global_mut<LotteryActivity>(admin_addr);
        
        // 验证活动 ID
        assert!(activity.activity_id == activity_id, ERROR_LOTTERY_NOT_EXISTS);
        
        // 验证活动还未启动
        assert!(!activity.lottery_started, ERROR_LOTTERY_NOT_STARTED);
        
        // 验证管理员权限
        assert!(activity.admin == admin_addr, ERROR_NOT_LOTTERY_ADMIN);
        
        let participant_count = vector::length(&activity.participants);
        let winners_count = activity.total_winners;
        
        // 确保中奖人数不超过参与者数
        assert!(winners_count <= participant_count, ERROR_INSUFFICIENT_REWARDS);
        
        // 简单的抽奖逻辑：选择前 winners_count 个参与者作为中奖者
        // 实际应用中应使用随机数，这里为了演示使用简单的逻辑
        let i = 0;
        while (i < winners_count) {
            let winner_addr = *vector::borrow(&activity.participants, i);
            vector::push_back(&mut activity.winners, winner_addr);
            
            let record = UserLotteryRecord {
                user_address: winner_addr,
                is_winner: true,
                reward_nft_id: option::none()
            };
            vector::push_back(&mut activity.winner_records, record);
            
            i = i + 1;
        };
        
        activity.lottery_started = true;
        activity.current_winners = winners_count;
        
        // 触发抽奖开始事件
        event::emit(LotteryStartedEvent {
            activity_id,
            winners: activity.winners
        });
    }

    /// ========== NFT 奖励管理函数 ==========

    /// 将 NFT 添加到抽奖活动的奖励池
    /// 
    /// 参数:
    /// - admin: 活动管理员签名者
    /// - activity_id: 活动 ID
    /// - nft_id: 要添加的 NFT ID（对象地址）
    entry public fun add_reward_nft(
        admin: &signer,
        activity_id: u64,
        nft_id: address
    ) {
        let admin_addr = signer::address_of(admin);
        
        // 获取抽奖活动
        assert!(exists<LotteryActivity>(admin_addr), ERROR_LOTTERY_NOT_EXISTS);
        let activity = borrow_global_mut<LotteryActivity>(admin_addr);
        
        // 验证活动 ID
        assert!(activity.activity_id == activity_id, ERROR_LOTTERY_NOT_EXISTS);
        
        // 验证管理员权限
        assert!(activity.admin == admin_addr, ERROR_NOT_LOTTERY_ADMIN);
        
        // 添加奖励 NFT
        vector::push_back(&mut activity.reward_nft_ids, nft_id);
    }

    /// 中奖用户领取 NFT
    /// 
    /// 参数:
    /// - user: 用户签名者
    /// - admin: 活动管理员地址
    /// - activity_id: 活动 ID
    /// - nft_index: 要领取的 NFT 在奖励池中的索引
    entry public fun claim_reward_nft(
        user: &signer,
        admin: address,
        activity_id: u64,
        nft_index: u64
    ) {
        let user_addr = signer::address_of(user);
        
        // 获取抽奖活动
        assert!(exists<LotteryActivity>(admin), ERROR_LOTTERY_NOT_EXISTS);
        let activity = borrow_global_mut<LotteryActivity>(admin);
        
        // 验证活动 ID
        assert!(activity.activity_id == activity_id, ERROR_LOTTERY_NOT_EXISTS);
        
        // 验证抽奖已开始
        assert!(activity.lottery_started, ERROR_LOTTERY_NOT_STARTED);
        
        // 检查用户是否中奖
        let is_winner = vector::contains(&activity.winners, &user_addr);
        assert!(is_winner, ERROR_NOT_WINNER);
        
        // 验证有足够的奖励 NFT
        assert!(nft_index < vector::length(&activity.reward_nft_ids), ERROR_INSUFFICIENT_REWARDS);
        
        // 获取奖励 NFT ID
        let nft_id = *vector::borrow(&activity.reward_nft_ids, nft_index);
        
        // 更新用户的领取记录
        let idx_len = vector::length(&activity.winner_records);
        let mut_idx = 0;
        while (mut_idx < idx_len) {
            let record = vector::borrow_mut(&mut activity.winner_records, mut_idx);
            if (record.user_address == user_addr) {
                record.reward_nft_id = option::some(nft_id);
                mut_idx = idx_len;  // 退出循环
            };
            mut_idx = mut_idx + 1;
        };
        
        // 触发奖励领取事件
        event::emit(WinnerClaimedRewardEvent {
            user_address: user_addr,
            activity_id,
            nft_id
        });
    }

    /// 模块初始化函数
    /// 在模块部署时自动调用，用于创建 NFT 集合和必要的存储结构
    /// 
    /// 参数:
    /// - sender: 部署模块的账户签名者
    fun init_module(sender: &signer) {
        // 创建一个命名对象作为集合创建者，用于管理集合
        let collection_creator_cref = object::create_named_object(sender, b"");
        
        // 生成集合创建者的扩展引用，用于后续生成签名者
        let collection_creator_extend_ref =
            object::generate_extend_ref(&collection_creator_cref);
        
        // 从集合创建者对象生成签名者，用于执行需要签名的操作
        let collection_creator_signer =
            &object::generate_signer(&collection_creator_cref);

        // 创建无限集合（unlimited collection），即不限制代币数量的集合
        // 参数说明：
        // - collection_creator_signer: 集合创建者签名者
        // - CollectionDescription: 集合描述
        // - CollectionName: 集合名称
        // - 版税设置: 5/100 = 5% 的版税，支付给 sender 地址
        // - CollectionURI: 集合的元数据 URI
        let collection_cref =
            collection::create_unlimited_collection(
                collection_creator_signer,
                string::utf8(CollectionDescription),
                string::utf8(CollectionName),
                option::some(royalty::create(5, 100, signer::address_of(sender))),
                string::utf8(CollectionURI)
            );

        // 从集合对象生成签名者
        let _ = object::generate_signer(&collection_cref);

        // 生成集合的可变引用，用于后续修改集合属性
        let _ = collection::generate_mutator_ref(&collection_cref);

        // 将集合引用存储到集合对象的存储中
        // 已在模块初始化中完成集合创建

        // 将签名者能力存储到集合创建者对象的存储中
        // 这样后续可以通过 extend_ref 生成签名者来执行操作
        move_to(
            collection_creator_signer,
            SignerCapabilityStore { extend_ref: collection_creator_extend_ref }
        );
    }

    /// 铸造 NFT 函数
    /// 创建一个新的 NFT 并将其转移给调用者
    /// 
    /// 参数:
    /// - sender: 调用此函数的账户签名者，将成为新铸造 NFT 的所有者
    entry public fun mint(sender: &signer) {
        // 从存储中获取集合创建者的扩展引用，并生成签名者
        // 这个签名者用于代表集合创建者执行操作（如创建代币）
        let collection_creator_signer =
            &object::generate_signer_for_extending(
                &SignerCapabilityStore[get_collection_creator_address()].extend_ref
            );
        
        // 初始化代币 URI 为基础 URI
        let url = string::utf8(TokenURI);

        // 创建编号代币（numbered token）
        // 参数说明：
        // - collection_creator_signer: 集合创建者签名者
        // - CollectionName: 集合名称
        // - CollectionDescription: 集合描述
        // - TokenPrefix: 代币名称前缀（如 "mfer #"）
        // - 空字符串: 代币名称后缀（这里为空）
        // - option::none(): 代币属性（这里不设置）
        // - 空字符串: 初始 URI（稍后会设置）
        let nft_cref =
            &token::create_numbered_token(
                collection_creator_signer,
                string::utf8(CollectionName),
                string::utf8(CollectionDescription),
                string::utf8(TokenPrefix),
                string::utf8(b""),
                option::none(),
                string::utf8(b"")
            );

        // 获取代币的索引号（编号），用于构建唯一的 URI
        let id = token::index<Token>(object::object_from_constructor_ref(nft_cref));
        
        // 将索引号追加到 URI 中
        url.append(string_utils::to_string(&id));
        
        // 追加文件扩展名 ".png"
        url.append(string::utf8(b".png"));

        // 从代币对象生成签名者
        let nft_signer = &object::generate_signer(nft_cref);

        // 生成代币的可变引用，用于修改代币属性（如设置 URI）
        let token_mutator_ref = token::generate_mutator_ref(nft_cref);

        // 设置代币的完整 URI（包含索引号和文件扩展名）
        token::set_uri(&token_mutator_ref, url);

        // 将代币从集合创建者转移给调用者（sender）
        // 这样调用者就成为新铸造 NFT 的所有者
        object::transfer(
            collection_creator_signer,
            object::object_from_constructor_ref<token::Token>(nft_cref),
            signer::address_of(sender)
        );

        // 将代币的各种引用存储到代币对象的存储中
        // 这些引用用于后续对代币进行操作（修改、销毁、转移等）
        move_to(
            nft_signer,
            TokenRefsStore {
                mutator_ref: token::generate_mutator_ref(nft_cref),      // 可变引用
                burn_ref: token::generate_burn_ref(nft_cref),            // 销毁引用
                extend_ref: object::generate_extend_ref(nft_cref),       // 扩展引用
                transfer_ref: option::some(object::generate_transfer_ref(nft_cref))  // 转移引用
            }
        );

        // 触发铸造事件，记录铸造信息
        // 这允许链下应用监听和响应 NFT 铸造事件
        event::emit(
            MintEvent {
                owner: signer::address_of(sender),                        // 新所有者地址
                token_id: object::address_from_constructor_ref(nft_cref)  // 代币 ID（对象地址）
            }
        );

    }

    /// 销毁 NFT 函数
    /// 销毁指定的 NFT，只有 NFT 的所有者才能销毁
    /// 
    /// 参数:
    /// - sender: 调用此函数的账户签名者
    /// - object: 要销毁的 NFT 对象
    entry fun burn(sender: &signer, object: Object<token::Token>) {
        // 验证调用者是否为 NFT 的所有者
        // 如果不是所有者，则抛出错误 ERROR_NOWNER
        assert!(object::is_owner(object, signer::address_of(sender)), ERROR_NOWNER);
        
        // 从代币对象的存储中提取 TokenRefsStore
        // 使用解构赋值获取 burn_ref，其他引用使用 _ 忽略
        let TokenRefsStore { mutator_ref: _, burn_ref, extend_ref: _, transfer_ref: _ } =
            move_from<TokenRefsStore>(object::object_address(&object));

        // 触发销毁事件，记录销毁信息
        event::emit(BurnEvent {
            owner: signer::address_of(sender),
            token_id: object::object_address(&object)
        });

        // 使用销毁引用来销毁代币
        // 这会永久删除代币，无法恢复
        token::burn(burn_ref);
    }

    /// 获取集合创建者地址
    /// 返回集合创建者对象的地址
    /// 
    /// 返回:
    /// - address: 集合创建者对象的地址
    #[view]
    public fun get_collection_creator_address(): address {
        // 根据合约地址和空种子创建对象地址
        // 这与 init_module 中创建命名对象时使用的参数一致
        object::create_object_address(&@my_first_nft, b"")
    }

    /// 获取集合对象
    /// 返回集合的 Object 引用，用于查询集合信息
    /// 
    /// 返回:
    /// - Object<collection::Collection>: 集合对象
    #[view]
    public fun get_collection_object(): Object<collection::Collection> {
        // 根据集合创建者地址和集合名称创建集合地址
        // 然后将地址转换为对象引用
        object::address_to_object(
            collection::create_collection_address(
                &get_collection_creator_address(),
                &string::utf8(CollectionName)
            )
        )
    }

    /// 测试专用初始化函数
    /// 仅在测试环境中使用，用于初始化模块
    /// 
    /// 参数:
    /// - sender: 测试账户签名者
    #[test_only]
    public fun init_for_test(sender: &signer) {
        init_module(sender)
    }

    /// ========== 查询函数 ==========

    /// 获取抽奖活动的参与者列表
    /// 
    /// 参数:
    /// - admin: 活动管理员地址
    /// - activity_id: 活动 ID
    /// 
    /// 返回:
    /// - vector<address>: 参与者地址列表
    #[view]
    public fun get_lottery_participants(admin: address, activity_id: u64): vector<address> {
        assert!(exists<LotteryActivity>(admin), ERROR_LOTTERY_NOT_EXISTS);
        let activity = borrow_global<LotteryActivity>(admin);
        assert!(activity.activity_id == activity_id, ERROR_LOTTERY_NOT_EXISTS);
        activity.participants
    }

    /// 获取抽奖活动的中奖者列表
    /// 
    /// 参数:
    /// - admin: 活动管理员地址
    /// - activity_id: 活动 ID
    /// 
    /// 返回:
    /// - vector<address>: 中奖者地址列表
    #[view]
    public fun get_lottery_winners(admin: &signer, activity_id: u64): vector<address> {
        let admin_addr = signer::address_of(admin);
        assert!(exists<LotteryActivity>(admin_addr), ERROR_LOTTERY_NOT_EXISTS);
        let activity = borrow_global<LotteryActivity>(admin_addr);
        assert!(activity.activity_id == activity_id, ERROR_LOTTERY_NOT_EXISTS);
        activity.winners
    }

    /// 获取抽奖活动的奖励 NFT 列表
    /// 
    /// 参数:
    /// - admin: 活动管理员地址
    /// - activity_id: 活动 ID
    /// 
    /// 返回:
    /// - vector<address>: 奖励 NFT ID 列表
    #[view]
    public fun get_reward_nfts(admin: address, activity_id: u64): vector<address> {
        assert!(exists<LotteryActivity>(admin), ERROR_LOTTERY_NOT_EXISTS);
        let activity = borrow_global<LotteryActivity>(admin);
        assert!(activity.activity_id == activity_id, ERROR_LOTTERY_NOT_EXISTS);
        activity.reward_nft_ids
    }

    /// 检查用户是否为抽奖中奖者
    /// 
    /// 参数:
    /// - user: 用户地址
    /// - admin: 活动管理员地址
    /// - activity_id: 活动 ID
    /// 
    /// 返回:
    /// - bool: 用户是否为中奖者
    #[view]
    public fun is_lottery_winner(user: address, admin: address, activity_id: u64): bool {
        assert!(exists<LotteryActivity>(admin), ERROR_LOTTERY_NOT_EXISTS);
        let activity = borrow_global<LotteryActivity>(admin);
        assert!(activity.activity_id == activity_id, ERROR_LOTTERY_NOT_EXISTS);
        vector::contains(&activity.winners, &user)
    }

    /// 获取抽奖活动的基本信息
    /// 
    /// 参数:
    /// - admin: 活动管理员地址
    /// - activity_id: 活动 ID
    /// 
    /// 返回:
    /// - (u64, u64, bool): (总中奖人数, 当前中奖人数, 是否已启动)
    #[view]
    public fun get_lottery_info(admin: address, activity_id: u64): (u64, u64, bool) {
        assert!(exists<LotteryActivity>(admin), ERROR_LOTTERY_NOT_EXISTS);
        let activity = borrow_global<LotteryActivity>(admin);
        assert!(activity.activity_id == activity_id, ERROR_LOTTERY_NOT_EXISTS);
        (activity.total_winners, activity.current_winners, activity.lottery_started)
    }
}
