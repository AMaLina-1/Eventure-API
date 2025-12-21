# Eventure 系統架構文檔

## 目錄
1. [系統架構（Macro）](#系統架構macro)
2. [代碼架構（Micro）](#代碼架構micro)
3. [Domain Model](#domain-model)
4. [與 CodePraise 的差異](#與-codepraise-的差異)

---

## 系統架構（Macro）

### 高層架構圖

```
┌─────────────────────────────────────────────────────────────────────┐
│                           CLIENTS                                   │
├─────────────────────────────────────────────────────────────────────┤
│  Browser (Web App)  │  Mobile (future)  │  API Consumers            │
└──────────┬──────────┴──────────┬────────┴─────────┬─────────────────┘
           │                     │                  │
           │ HTTP/HTTPS          │ HTTP/REST        │ HTTP/REST
           │                     │                  │
    ┌──────▼──────────┐  ┌───────▼────────┐  ┌──────▼─────────┐
    │  app-Eventure   │  │  api-Eventure  │  │    Workers     │
    │  (Web App)      │  │  (REST API)    │  │  (Background)  │
    └────────┬────────┘  └────────┬───────┘  └────────┬───────┘
             │ Session            │ Pure REST         │ SQS Queue
             │ Rack Cache         │ JSON              │ (AWS SQS)
             └────────┬───────────┴───────────────────┘
                      │ Sequel ORM
                      │
            ┌─────────▼──────────┐     ┌─────────────────────────────────────────────────────────────────────────────┐
            │   SQLite Database  │     │                                 EXTERNAL APIs                               │
            │  (development)     │     ├─────────────────────────────────────────────────────────────────────────────┤
            │                    │     │  hccg       │  Taipei  │  New-Taipei  │  Taichung │  Tainan  │  Kaohsiung   │
            │ - activities       │     │  (HTTP API) │ (HTTP)   │ (HTTP)       │ (HTTP)    │ (HTTP)   │ (HTTP)       │
            │ - tags             │     │  WebOpenAPI │ API      │ API          │ API       │ API      │ API          │
            │ - relatedata       │     └─────────────────────────────────────────────────────────────────────────────┘
            │ - activities_tags  │
            └────────────────────┘
```

### 核心組件說明

#### 1. **app-Eventure** (Web Application)
- **Type**: Server-rendered Rack/Roda web application
- **Purpose**: 使用者界面，提供活動搜尋、篩選、和收藏功能
- **Key Protocols**: 
  - HTTP GET/POST to itself
  - Rack::Session::Cookie for stateful sessions
  - Rack::Cache for HTTP caching
- **Key Features**:
  - Session 管理：filters, user_likes
  - 表單驗證（dry-struct/dry-types）
  - 視圖渲染（Slim 模板）
  - 前端路由管理

#### 2. **api-Eventure** (REST API)
- **Type**: Stateless Rack/Roda REST API
- **Purpose**: 為前端和其他系統提供 JSON API
- **Key Protocols**: 
  - HTTP REST (GET, POST, PUT, DELETE)
  - JSON request/response bodies
  - Roar decorators for serialization
- **Key Endpoints**:
  - `GET /activities` - 列出所有活動
  - `GET /activities/:serno` - 活動詳情
  - `GET /activities/filter` - 高級篩選
  - `POST /activities/:serno/like` - 點擊喜歡
  - `GET /tags` - 列出標籤
  - `GET /cities` - 列出城市
  - `GET /districts` - 列出區域

#### 3. **Workers** (Background Job Processing)
- **Type**: Shoryuken workers (AWS SQS consumer)
- **Purpose**: **目前未實現**，但架構已準備
- **Would Handle**:
  - 定期同步外部 APIs 的活動數據
  - 批量處理重複數據
  - 後台分析和聚合

### 數據流

#### Flow 1: 用戶查看活動列表
```
Browser 
  ↓ (GET /activities)
app-Eventure Controller
  ↓ (調用 Service)
FilteredActivities Service (Dry::Transaction)
  ├→ fetch_all_activities
  ├→ filter_by_tags
  ├→ filter_by_city
  ├→ filter_by_districts
  ├→ filter_by_dates
  └→ wrap_in_response
  ↓ (Repository pattern)
Repository::Activities (Sequel ORM)
  ↓ (SQL query)
Database (SQLite)
  ↓ (rebuild entities)
Activity Entities + Value Objects
  ↓ (Slim template)
HTML Response
  ↓
Browser Render
```

#### Flow 2: REST API 調用
```
External Client
  ↓ (HTTP GET /activities)
api-Eventure Controller
  ↓ (調用 Service)
ListActivity Service
  ↓ (Repository pattern)
Repository::Activities
  ↓ (Database)
Activity Entities
  ↓ (Roar Representer)
JSON Response
  ↓
Client
```

#### Flow 3: 用戶點擊喜歡
```
Browser
  ↓ (POST /activities/:serno/like)
app-Eventure Controller
  ↓ (調用 Service)
ToggleLike Service
  ├→ Session[:user_likes] 更新 (in-memory)
  └→ Activity.add_likes() 或 remove_likes()
  ↓ (Repository)
Repository::Activities.update_likes()
  ↓ (SQL update)
Database (likes_count column)
  ↓
Success Response
  ↓
Browser (update UI)
```

### 緩存策略

#### Rack::Cache (HTTP 層)
- **Development**: 檔案系統快取 (`_cache/rack/`)
- **Production**: Redis 快取 (`REDISCLOUD_URL`)
- **目的**: 減少重複的同樣 GET 請求
- **Cache-Control Headers**: 
  ```ruby
  response.cache_control public: true, max_age: 300  # 5分鐘
  ```

#### Session 快取
```ruby
session[:filters] ||= { tag: [], city: nil, districts: [], ... }
session[:user_likes] ||= []
```
- 存儲在加密 Cookie 中
- 用於保持篩選狀態和用戶喜歡列表

### 外部 APIs 集成

每個城市有獨立的 Mapper 類：
```
api-Eventure/app/infrastructure/
  ├── hccg/          # 新竹市政府
  │   ├── gateways/api.rb
  │   └── mappers/activity_mapper.rb
  ├── taipei/        # 台北市
  ├── new_taipei/    # 新北市
  ├── taichung/      # 台中市
  ├── tainan/        # 台南市
  └── kaohsiung/     # 高雄市
```

**Activity Service** 聚合所有城市的 API：
```ruby
def fetch_activities(limit = 100)
  hccg_activities + taipei_activities + new_taipei_activities 
    + taichung_activities + tainan_activities + kaohsiung_activities
end
```

- **協議**: HTTP GET
- **格式**: JSON 響應
- **同步方式**: 同步拉取（在用戶請求時）
- **失敗處理**: 有一個城市失敗時，繼續獲取其他城市

### 數據庫架構

#### 表結構
```sql
activities
├── id (PK)
├── serno (UK, 來自外部 API)
├── name
├── detail
├── location
├── voice
├── organizer
├── start_time
├── end_time
├── likes_count
├── created_at
└── updated_at

tags
├── id (PK)
├── tag (UK)
└── created_at

activities_tags (Join Table)
├── activity_id (FK)
├── tag_id (FK)
└── pk: (activity_id, tag_id)

relatedata
├── id (PK)
├── relate_title
├── relate_url
├── created_at

activities_relatedata (Join Table)
├── activity_id (FK)
├── relatedata_id (FK)
└── pk: (activity_id, relatedata_id)
```

#### 關係
- **Activity** ↔ **Tags**: 多對多（一個活動多個標籤）
- **Activity** ↔ **RelateData**: 多對多（相關鏈接）

---

## 代碼架構（Micro）

### 分層架構

採用 **Clean Architecture** 模式：

```
app-Eventure / api-Eventure
├── app/
│   ├── application/        # Application Layer (Use Cases)
│   │   ├── controllers/    # HTTP handlers
│   │   ├── services/       # Business logic (Dry::Transaction)
│   │   └── requests/       # Request objects (only in api-Eventure)
│   │
│   ├── domain/             # Domain Layer (Business Rules)
│   │   ├── entities/       # Domain entities (Activity, User, Tag, etc.)
│   │   └── values/         # Value objects (Location, ActivityDate, Filter, etc.)
│   │
│   ├── infrastructure/     # Infrastructure Layer (External APIs, DB)
│   │   ├── database/       # ORM, migrations, repositories
│   │   ├── cache/          # Redis/Rack cache adapters
│   │   ├── gateways/       # External API clients
│   │   ├── hccg/           # City-specific mappers
│   │   ├── taipei/
│   │   ├── new_taipei/
│   │   ├── taichung/
│   │   ├── tainan/
│   │   └── kaohsiung/
│   │
│   └── presentation/       # Presentation Layer (Views, Serialization)
│       ├── controllers/    # (for app-Eventure routing)
│       ├── representers/   # Roar decorators (for api-Eventure JSON)
│       ├── responses/      # Response objects
│       └── views_html/     # Slim templates (for app-Eventure)
│
├── config/
│   ├── environment.rb      # App setup, DB, cache config
│   └── secrets.yml         # Environment variables
│
├── db/
│   ├── migrations/         # Sequel migrations
│   └── local/              # SQLite database file
│
├── spec/
│   ├── helpers/
│   ├── tests/              # Unit tests
│   └── tests_acceptance/   # Integration tests
│
└── workers/
    ├── worker.rb           # Shoryuken worker class
    └── shoryuken*.yml      # Worker config
```

---

## Domain Model

### 聚合根（Aggregate Root）

#### 🎯 **Activity（活動）** - Primary Aggregate
```ruby
class Activity < Dry::Struct
  attribute :serno,        Strict::String          # External API ID
  attribute :name,         Strict::String          # Event name
  attribute :detail,       Strict::String          # Description
  attribute :location,     Eventure::Value::Location
  attribute :voice,        Strict::String          # Accessibility (e.g., "語音導覽")
  attribute :organizer,    Strict::String          # 主辦單位
  attribute :tags,         Array.of(Tag)           # Multiple tags
  attribute :relate_data,  Array.of(RelateData)    # Related URLs/info
  attribute :activity_date, Eventure::Value::ActivityDate
  
  # Behavior
  def add_likes
    @likes_count += 1
  end
  
  def remove_likes
    @likes_count -= 1 if @likes_count.positive?
  end
  
  def status  # Archived, Expired, Ongoing, Upcoming, Scheduled
    activity_date.status
  end
  
  def duration  # "2 days 3 hours 45 minutes"
    activity_date.duration
  end
end
```

**Why Activity is the Aggregate Root:**
- 代表系統的核心業務對象
- 其他實體（Tag, RelateData）都從屬於它
- 控制了活動的生命週期和狀態變更

---

### 實體（Entities）

#### **User（用戶）**
```ruby
class User < Dry::Struct
  attribute :user_id,      Strict::Integer
  attribute :user_date,    Array.of(Date)      # [start_date, end_date]
  attribute :user_theme,   Array.of(String)    # [tag1, tag2, ...]
  attribute :user_region,  Array.of(String)    # [city1, district1, ...]
  attribute :user_saved,   Array                # Saved activity sernos
  attribute :user_likes,   Array                # Liked activity sernos
  
  # 業務邏輯
  def add_theme(theme)
    return self if user_theme.include?(theme)
    new(user_theme: user_theme + [theme])
  end
  
  def add_region(region)
    return self if user_region.include?(region)
    new(user_region: user_region + [region])
  end
  
  def to_filter
    # 轉換為 Filter value object 用於篩選
    Value::Filter.new(
      filter_date: user_date,
      filter_theme: user_theme,
      filter_region: user_region
    )
  end
end
```

#### **Tag（標籤）**
```ruby
class Tag < Dry::Struct
  attribute :tag, String  # "文化", "教育", "運動", etc.
end
```

#### **RelateData（相關數據）**
```ruby
class RelateData < Dry::Struct
  attribute :relatedata_id, Integer.optional
  attribute :relate_title,  String   # 連結標題
  attribute :relate_url,    String   # 連結 URL
end
```

---

### 值對象（Value Objects）

#### **Location（位置）** ⭐
```ruby
class Location < Dry::Struct
  attribute :building, Strict::String      # 詳細地址
  attribute? :city_name, Strict::String.optional.default(nil)  # 城市名稱
  
  # 核心業務邏輯：正規化城市名稱
  def city
    self.class.normalize_city(city_name)  # 將"臺"轉換為"台"
  end
  
  def to_s
    building
  end
  
  # 智慧地在地址前加上城市名稱（避免重複）
  def self.normalize_building(building, city_name)
    building_str = building.to_s.strip
    normalized_city = normalize_city(city_name)
    
    return normalized_city if building_str.empty?
    return building_str if normalized_city.empty?
    
    prefix_city_unless_present(building_str, normalized_city)
  end
  
  def self.normalize_city(str)
    str.to_s.strip.tr('臺', '台')
  end
end
```

**Interesting Logic**: 
- 處理台灣地名的"臺/台"不一致問題
- 避免地址重複包含城市名稱

---

#### **ActivityDate（活動時間）** ⭐
```ruby
class ActivityDate < Dry::Struct
  attribute :start_time, Strict::DateTime
  attribute :end_time,   Strict::DateTime
  
  # 計算活動持續時間
  def duration
    diff = ((end_time - start_time) * 24 * 60).to_i
    day, remain = diff.divmod(24 * 60)
    hour, minute = remain.divmod(60)
    "#{day} days #{hour} hours #{minute} minutes"
  end
  
  # 活動狀態機
  def status
    now = ::DateTime.now
    return check_past(now, 3) if end_time < now
    return check_future(now, 7) if now < start_time
    'Ongoing'
  end
  
  private
  
  def check_past(now, offset)
    end_time < now - offset ? 'Archived' : 'Expired'
  end
  
  def check_future(now, offset)
    now + offset < start_time ? 'Scheduled' : 'Upcoming'
  end
end
```

**Status State Machine:**
```
               7 days before
                    ↓
        Scheduled ← Upcoming → Ongoing → Expired → Archived
                                           ↑
                                    3 days after end
```

---

#### **Filter（篩選條件）** ⭐⭐⭐
```ruby
class Filter < Dry::Struct
  attribute :filter_date,  Array.of(Date).default([].freeze)
  attribute :filter_theme, Array.of(String).default([].freeze)
  attribute :filter_region, Array.of(String).default([].freeze)
  
  # 核心業務邏輯：篩選匹配
  def match_filter?(activity)
    date_ok?(activity.start_time, activity.end_time) &&
      theme_ok?(activity) &&
      region_ok?(activity)
  end
  
  private
  
  def date_ok?(start_time, end_time)
    start_date, end_date = filter_date
    return true unless start_date && end_date
    
    end_time >= start_date.to_datetime &&
      start_time <= end_date.to_datetime
  end
  
  def theme_ok?(activity)
    return true if filter_theme.empty?
    
    activity_tag_values = Array(activity.tags).map(&:tag)
    activity_tag_values.intersect?(filter_theme)
  end
  
  def region_ok?(activity)
    return true if filter_region.empty?
    
    city_value = activity.city.to_s
    district_value = activity.district.to_s
    
    filter_region.include?(city_value) || 
      filter_region.include?(district_value)
  end
end
```

**Interesting Logic:**
- 多維度複合篩選（日期 ∧ 主題 ∧ 地區）
- 時間範圍重疊判斷
- 集合交集判斷（主題標籤）

---

#### **Other Value Objects**
- **Saved**: 保存的活動列表
- **ActivityList**: 活動列表包裝
- 所有用 **Dry::Struct** 實現，自動獲得：
  - 不可變性 (Immutability)
  - 結構化驗證 (Dry::Types)
  - `.to_h` 轉換

---

### 業務邏輯核心

#### 在 Domain Layer 實現的業務規則：

1. **活動狀態管理** (`ActivityDate.status`)
   - 根據時間自動計算狀態
   - 狀態轉換規則內嵌

2. **篩選邏輯** (`Filter.match_filter?`)
   - 多維篩選的組合邏輯
   - 時間範圍重疊判斷
   - 標籤和地區匹配

3. **喜歡計數** (`Activity.add_likes/remove_likes`)
   - 簡單但原子的操作
   - 防止負數

4. **城市正規化** (`Location.normalize_city`)
   - 處理地名變體（臺/台）
   - 地址完整性檢查

5. **用戶偏好管理** (`User` 方法)
   - 主題、地區、日期範圍管理
   - 喜歡/收藏列表操作
   - 不可變的 Entity 更新

---

## Application Layer（應用層）

### Service Objects（業務用例）

#### api-Eventure Services:

```ruby
class ListActivity
  include Dry::Transaction
  
  step :fetch_activities
  
  # 簡單用例：獲取所有活動
end

class FilteredActivities
  include Dry::Transaction
  
  step :fetch_all_activities
  step :filter_by_tags
  step :filter_by_city
  step :filter_by_districts
  step :filter_by_dates
  step :wrap_in_response
  
  # 複雜用例：多步驟篩選流程
end

class ToggleLike
  include Dry::Monads[:result]
  
  def call(session:, serno:)
    activity = find_activity(serno)
    return Failure(...) if activity.nil?
    
    toggle_like!(session, activity, serno)
    persist_likes(activity)
    
    Success(...)
  end
  
  # 序列化操作：toggle + persist
end

class UpdateLikes
  include Dry::Monads[:result, :do]
  
  # 使用 do 記號進行步驟化錯誤處理
end

class SearchedActivities
  # 關鍵字搜尋
end

class ListTag, ListCity, ListDistrict
  # 提供篩選選項
end
```

#### app-Eventure Services:

```ruby
class FilteredActivities
  include Dry::Transaction
  
  step :validate_filter
  step :request_activity          # 調用 api-Eventure
  step :reify_activity            # 反序列化
end

class SearchedActivities
  # 關鍵字搜尋
end

class LikedActivities
  # 獲取用戶喜歡的活動
end

class UpdateLikeCounts
  # 同步喜歡計數
end
```

**Service 設計特點:**
- 使用 **Dry::Transaction** 實現流程控制
- 使用 **Dry::Monads** 實現錯誤處理 (Success/Failure)
- 每個 Service = 一個清晰的用例
- Services 之間可以嵌套調用

---

## Infrastructure Layer（基礎設施層）

### Repository Pattern
```ruby
module Repository
  class Activities
    def self.all
      Database::ActivityOrm.all.map { |db| rebuild_entity(db) }
    end
    
    def self.find_serno(serno)
      rebuild_entity(Database::ActivityOrm.first(serno: serno))
    end
    
    def self.create(entities)
      Array(entities).map do |entity|
        db_activity = find_or_create_activity(entity)
        assign_tags(db_activity, entity.tags)
        assign_relate_data(db_activity, entity.relate_data)
        rebuild_entity(db_activity)
      end
    end
    
    def self.update_likes(activity)
      db_record = Database::ActivityOrm.first(serno: activity.serno)
      db_record.update(likes_count: activity.likes_count)
      rebuild_entity(db_record)
    end
    
    private
    
    def self.rebuild_entity(db_record)
      # 將 ORM 對象轉換為 Domain Entity
      Entity::Activity.new(...)
    end
  end
  
  class Tags
    def self.find_or_create(entity)
      # find-or-create 模式
    end
  end
  
  class Relatedata
    def self.find_or_create(entity)
      # find-or-create 模式
    end
  end
end
```

**Repository 的責任:**
- 將 DB 記錄轉換為 Domain Entities
- 隔離 ORM 細節
- 管理多表聯接（Activity ↔ Tags, RelateData）

---

### ORM 層（Sequel）
```ruby
module Database
  class ActivityOrm < Sequel::Model(:activities)
    many_to_many :tags,
                 class: :'Eventure::Database::TagOrm',
                 join_table: :activities_tags,
                 left_key: :activity_id,
                 right_key: :tag_id
    
    many_to_many :relatedata,
                 class: :'Eventure::Database::RelatedataOrm',
                 join_table: :activities_relatedata,
                 left_key: :activity_id,
                 right_key: :relatedata_id
  end
  
  class TagOrm < Sequel::Model(:tags)
    many_to_many :activities
  end
  
  class RelatedataOrm < Sequel::Model(:relatedata)
    many_to_many :activities
  end
end
```

---

### City Mappers（外部 API 適配層）

每個城市有獨立的 Mapper 處理其 API 格式：

```
hccg/mappers/activity_mapper.rb
├── def find(limit)           # HTTP GET to API
├── def to_attr_hash(entity)  # Entity → Hash
└── class DataMapper
    ├── def to_entity         # Raw API JSON → Domain Entity
    ├── def serno
    ├── def name
    ├── def location
    ├── def activity_date
    └── ...
```

**Mapper 的作用:**
- 轉換來自不同外部 API 的數據格式
- 統一為 `Eventure::Entity::Activity`
- 處理日期格式、城市名稱等差異

**ActivityService 聚合：**
```ruby
class ActivityService
  def fetch_activities(limit = 100)
    hccg_activities + taipei_activities + new_taipei_activities 
      + taichung_activities + tainan_activities + kaohsiung_activities
  end
  
  def save_activities(top)
    entities = fetch_activities(top)
    Repository::For.entity(entities.first).create(entities)
  end
end
```

---

## Presentation Layer（表現層）

### api-Eventure: Roar Representers
```ruby
module Representer
  class ActivityList < Roar::Decorator
    include Roar::JSON
    
    collection :activities, extend: ActivitySingle, class: OpenStruct
  end
  
  class ActivitySingle < Roar::Decorator
    include Roar::JSON
    
    property :serno
    property :name
    property :detail
    property :location
    property :voice
    property :organizer
    property :tags
    property :relate_data
    property :start_time
    property :end_time
    property :likes_count
    property :status
    property :duration
  end
end
```

**Roar 的作用:**
- Decorator 模式
- 自動 JSON 序列化/反序列化
- 與 ORM/Entity 解耦

### app-Eventure: Slim 模板 + View Objects
```ruby
module Views
  class ActivityList
    def initialize(activities)
      @activities = activities
    end
  end
  
  class Filter
    def initialize(filter_hash)
      @filters = filter_hash
    end
    
    def current_city
      @filters[:city]
    end
  end
  
  class FilterOption
    # 根據已選擇的篩選條件生成可選項
  end
end
```

在 Slim 模板中使用：
```slim
- @filtered_activities.each do |activity|
  .activity-card
    h3= activity.name
    p= activity.location
    .tags
      - activity.tags.each do |tag|
        .tag= tag.tag
```

---

## 並發和緩存

### Rack::Cache（HTTP 層緩存）

**Development:**
```ruby
use Rack::Cache,
    verbose: true,
    metastore: 'file:_cache/rack/meta',
    entitystore: 'file:_cache/rack/body'
```

**Production (Redis):**
```ruby
use Rack::Cache,
    verbose: true,
    metastore: "#{REDISCLOUD_URL}/0/metastore",
    entitystore: "#{REDISCLOUD_URL}/0/entitystore"
```

**Cache Headers:**
```ruby
response['Content-Type'] = 'text/html; charset=utf-8'
response.cache_control public: true, max_age: 300  # 5 分鐘
response.expires 300, public: true
```

**效果:**
- GET `/activities` 的結果在 5 分鐘內快取
- 瀏覽器和 CDN 都會緩存
- 減少數據庫和外部 API 查詢

---

### Session 緩存

```ruby
session[:filters] ||= {
  tag: [],
  city: nil,
  districts: [],
  start_date: nil,
  end_date: nil
}
session[:user_likes] ||= []
```

**特點:**
- 存儲在加密 Cookie 中（`Rack::Session::Cookie`）
- 用戶會話級別的狀態
- 用於保持篩選狀態和喜歡列表

---

### 並發性

**當前實現:**
- SQLite 用於開發（單線程）
- 生產環境應遷移到 PostgreSQL
- Sequel ORM 提供基本的連接池支持

**Race Condition 處理（在 Repository 中）:**
```ruby
def self.assign_tags(db_activity, tags)
  db_activity.remove_all_tags
  
  Array(tags).each do |tag|
    tag_orm = find_or_create_tag(tag)
    db_activity.add_tag(tag_orm)
  end
end
```

**潛在問題:**
- 多個進程同時更新 likes_count 時可能丟失更新
- 應使用數據庫級別的鎖或原子操作

---

## Background Worker（後台處理）

### 現狀

**代碼框架已準備：**
```ruby
# workers/worker.rb
class Worker
  include Shoryuken::Worker
  
  shoryuken_options queue: config.QUEUE_URL, auto_delete: true
  
  def perform(_sqs_msg, request)
    # 當前未實現
  end
end
```

**基礎設施已準備：**
```
Gemfile:
  gem 'aws-sdk-sqs'
  gem 'shoryuken'
  gem 'concurrent-ruby'

config/
  shoryuken.yml        # Worker config
  shoryuken_dev.yml
  shoryuken_test.yml
```

### 為什麼需要 Background Worker？

1. **異步更新活動數據**
   - 定期從 6 個城市的 API 同步最新活動
   - 不阻塞用戶請求

2. **批量數據處理**
   - 去重（同一活動在多個城市出現）
   - 數據聚合和轉換

3. **系統解耦**
   - API 同步與 UI 分離
   - 支持未來的分佈式架構

### 未來實現

```ruby
class ActivitySyncWorker
  include Shoryuken::Worker
  
  def perform(_sqs_msg, city_name)
    service = ActivityService.new
    activities = service.fetch_activities_for_city(city_name, limit: 100)
    service.save_activities(activities)
    
    notify_completion(city_name)
  end
end

# 定時調用（使用 cron job 或 CloudWatch Events）
%w[hccg taipei new_taipei taichung tainan kaohsiung].each do |city|
  ActivitySyncWorker.perform_async(city)
end
```

---

## 與 CodePraise 的差異

### 相似之處

✅ **都採用 Clean Architecture**
- Domain / Application / Infrastructure / Presentation 分層
- Repository 模式隔離 ORM
- Service 層實現業務邏輯

✅ **都使用 Dry-rb 生態**
- Dry::Struct 定義 Entities
- Dry::Types 驗證
- Dry::Transaction 流程控制
- Dry::Monads 錯誤處理

✅ **都是 Rack/Roda 應用**
- Web 框架
- 路由管理
- Middleware 支持

---

### 主要差異

#### 1. **Domain Model 的複雜度** ⭐⭐⭐

**CodePraise:**
- 專注於代碼倉庫分析
- Domain: Project, Repository, Contributor, Metrics
- 邏輯相對簡單（複製 Git 倉庫、解析代碼）

**Eventure:**
- 專注於事件發現
- Domain: Activity, User, Filter, Location, ActivityDate
- **邏輯更複雜**：
  - 多維複合篩選 (Filter)
  - 狀態機 (ActivityDate status)
  - 地名正規化 (Location)
  - 聚合多個外部 API

**勝者**: Eventure 的 Domain Model **更豐富、更有趣**

---

#### 2. **數據來源** ⭐⭐

**CodePraise:**
- 單一來源：Git 倉庫 (GitHub API)
- 直接克隆和分析

**Eventure:**
- **多來源**: 6 個城市的獨立 API
  - 新竹市政府 WebOpenAPI
  - 台北市、新北市、台中市、台南市、高雄市
- **數據聚合和統一**: ActivityService
- **格式差異處理**: 城市特定的 Mapper

**特色**: **MapperPattern 的活用** - 每個外部 API 有不同的數據格式和響應結構

---

#### 3. **背景任務** ⭐⭐

**CodePraise:**
- Worker 的目的很明確：克隆 Git 倉庫
- 通過 SQS 隊列傳遞任務

**Eventure:**
- Worker 框架已準備但**未實現**
- 未來用途：定期同步多個城市的 API 數據
- **更複雜的場景**: 
  - 需要定時任務（不是事件驅動）
  - 需要批量處理和去重
  - 需要故障恢復機制

---

#### 4. **緩存策略** ⭐⭐

**CodePraise:**
- 簡單：主要緩存 Git 分析結果

**Eventure:**
- **多層緩存**:
  - Rack::Cache (HTTP 層) - 5 分鐘緩存
  - Session (用戶級) - 篩選條件
  - Redis (生產環境)
- **原因**: 頻繁查詢外部 API，需要減少網絡往返

---

#### 5. **User / Session 管理** ⭐

**CodePraise:**
- 簡單的 GitHub 登陸集成

**Eventure:**
- **無身份驗證** ❌
- **Session 管理**: 
  - 用戶偏好（篩選條件）保存在 Session
  - 喜歡列表存儲在 Session（客戶端 Cookie）
  - **無數據庫持久化** - 每次新 Session 重置
- **改進空間**: 
  - 應添加登陸功能
  - 將用戶偏好保存到數據庫

---

#### 6. **API 設計**

**CodePraise:**
- 主要是 Web 應用
- API 只是輔助

**Eventure:**
- **雙重應用**:
  - api-Eventure: 純 REST API
  - app-Eventure: Web 應用（調用 API）
- **API-First 設計**: API 是核心，Web 應用是消費者
- **協議**: REST + JSON

---

#### 7. **測試策略**

**Eventure (app-Eventure):**
```ruby
group :test do
  gem 'headless'          # 無頭瀏覽器
  gem 'page-object'       # UI 測試
  gem 'selenium-webdriver'
  gem 'watir'             # Web 自動化測試
end
```

**特色**: **驗收測試 (Acceptance Tests)** - 測試整個用戶流程，不僅是單元測試

---

### 最有趣的部分（相比 CodePraise）

| 特性 | 有趣度 | 原因 |
|------|--------|------|
| **多源數據聚合** | ⭐⭐⭐⭐⭐ | 6 個城市 API，Mapper 模式 |
| **複合篩選邏輯** | ⭐⭐⭐⭐ | Filter value object，多維篩選 |
| **狀態機** | ⭐⭐⭐⭐ | ActivityDate.status 自動轉換 |
| **地名正規化** | ⭐⭐⭐ | 處理"臺/台"變體 |
| **API-First 設計** | ⭐⭐⭐⭐ | api-Eventure 和 app-Eventure 分離 |
| **HTTP 快取策略** | ⭐⭐⭐ | Rack::Cache + Redis |

---

## 總結

### Eventure 的核心優勢

1. **富有表現力的 Domain Model**
   - Value Objects 封裝複雜邏輯
   - State Machine (ActivityDate)
   - Rich Filter Object

2. **優雅的數據集成**
   - Mapper Pattern 統一異構 API
   - Service 層聚合邏輯
   - 自動故障降級

3. **清潔的架構分離**
   - api-Eventure (無狀態 API)
   - app-Eventure (Web UI with Session)
   - 共享 Domain + Infrastructure

4. **實用的設計模式**
   - Repository Pattern
   - Mapper Pattern
   - Service 層（Dry::Transaction）
   - Value Objects（Dry::Struct）

### 可以改進的地方

- ❌ 沒有用戶認證
- ❌ 用戶偏好沒有持久化
- ❌ Background Worker 未實現
- ❌ 缺少 API 文檔 (OpenAPI/Swagger)
- ❌ 沒有分佈式事務處理機制

---
