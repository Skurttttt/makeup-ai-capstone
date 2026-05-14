# FaceTune Beauty — ERD & DFD

> Generated from the live database schema (`database/schema.sql`, `database/paymongo_schema.sql`, `database/create_products_schema.sql`).
> Three roles: **User** (buyer/scanner), **Client** (business/seller), **Admin** (platform manager).

---

## 1. Entity Relationship Diagram (ERD)

```mermaid
erDiagram

    AUTH_USERS {
        uuid      id               PK
        string    email
        string    encrypted_password
    }

    ACCOUNTS {
        uuid      id               PK
        string    email
        string    full_name
        string    role
        string    account_type
        string    client_type
        string    business_name
        string    business_type
        string    business_phone
        string    business_address
        string    business_logo_url
        boolean   business_verified
        string    avatar_url
        string    bio
        string    created_at
        string    updated_at
    }

    VERIFICATION_CODES {
        uuid      id               PK
        string    email
        string    code
        integer   attempts
        string    expires_at
        string    verified_at
    }

    SCANS {
        uuid      id               PK
        uuid      user_id          FK
        string    look_name
        string    image_url
        string    image_path
        string    face_data
        string    skin_tone
        string    face_shape
        string    created_at
        string    updated_at
    }

    FAVORITES {
        uuid      id               PK
        uuid      user_id          FK
        string    look_name
        string    created_at
    }

    SUBSCRIPTION_PLANS {
        uuid      id                    PK
        string    name
        string    display_name
        string    description
        numeric   price
        string    currency
        string    billing_period
        integer   daily_scan_limit
        string    available_looks
        boolean   can_save_results
        boolean   can_export_hd
        boolean   can_use_filters
        boolean   priority_processing
        boolean   remove_watermark
        boolean   access_exclusive_looks
        string    badge_text
        string    badge_color
        boolean   is_active
    }

    USER_SUBSCRIPTIONS {
        uuid      id                        PK
        uuid      user_id                   FK
        uuid      plan_id                   FK
        string    status
        string    started_at
        string    current_period_start
        string    current_period_end
        string    canceled_at
        numeric   amount_paid
        string    transaction_id
        string    payment_provider
        string    provider_subscription_id
        string    provider_customer_id
        string    provider_payment_id
        boolean   auto_renew
    }

    PRODUCTS {
        uuid      id               PK
        uuid      business_id      FK
        string    name
        string    description
        numeric   price
        string    currency
        string    image_url
        string    product_link
        integer   stock_quantity
        string    variations
        string    category
        boolean   is_active
        string    created_at
        string    updated_at
    }

    ORDERS {
        uuid      id                           PK
        uuid      buyer_id                     FK
        string    status
        string    currency
        numeric   subtotal
        numeric   tax
        numeric   shipping
        numeric   total
        string    payment_provider
        string    provider_checkout_session_id
        string    provider_payment_id
        string    provider_status
        string    created_at
        string    updated_at
    }

    ORDER_ITEMS {
        uuid      id             PK
        uuid      order_id       FK
        uuid      product_id     FK
        uuid      business_id    FK
        integer   quantity
        numeric   unit_price
        numeric   total_price
        string    created_at
    }

    PAYMENT_SESSIONS {
        uuid      id                           PK
        uuid      user_id                      FK
        string    session_type
        string    status
        numeric   amount
        string    currency
        string    payment_provider
        string    provider_checkout_session_id
        string    provider_checkout_url
        string    provider_payment_id
        string    metadata
        string    created_at
        string    updated_at
    }

    PAYMENT_EVENTS {
        uuid      id                 PK
        string    payment_provider
        string    event_type
        string    provider_event_id
        string    payload
        string    created_at
    }

    PROFITS {
        uuid      id           PK
        string    profit_date
        numeric   amount
        string    source
        string    created_at
    }

    AUDIT_LOGS {
        uuid      id          PK
        uuid      actor_id    FK
        string    action
        string    target
        string    metadata
        string    created_at
    }

    %% Relationships

    AUTH_USERS         ||--||   ACCOUNTS           : "extends"
    ACCOUNTS           ||--o{   SCANS              : "creates"
    ACCOUNTS           ||--o{   FAVORITES          : "saves"
    ACCOUNTS           ||--o{   USER_SUBSCRIPTIONS : "holds"
    ACCOUNTS           ||--o{   PRODUCTS           : "lists"
    ACCOUNTS           ||--o{   ORDERS             : "places"
    ACCOUNTS           ||--o{   ORDER_ITEMS        : "sells via"
    ACCOUNTS           ||--o{   PAYMENT_SESSIONS   : "initiates"
    ACCOUNTS           ||--o{   AUDIT_LOGS         : "triggers"
    SUBSCRIPTION_PLANS ||--o{   USER_SUBSCRIPTIONS : "defines"
    ORDERS             ||--o{   ORDER_ITEMS        : "contains"
    PRODUCTS           ||--o{   ORDER_ITEMS        : "included in"
```

---

## 2. DFD — Level 0: Context Diagram

High-level view of the whole system and all external actors.

```mermaid
flowchart LR
    subgraph HUMANS["Human Actors"]
        USER["User\nbuy / scan / subscribe"]
        CLIENT["Client\nbusiness / seller"]
        ADMIN["Admin"]
    end

    SYSTEM(("FaceTune\nBeauty App"))

    subgraph SERVICES["External Services"]
        AUTH{{"Supabase Auth"}}
        PAYMONGO{{"PayMongo\npayment gateway"}}
    end

    USER     -->|sign up, scan, subscribe, buy| SYSTEM
    SYSTEM   -->|AI looks, orders, receipts| USER
    CLIENT   -->|register business, list products| SYSTEM
    SYSTEM   -->|sales reports, order alerts| CLIENT
    ADMIN    -->|manage users, plans, products| SYSTEM
    SYSTEM   -->|analytics, audit logs| ADMIN
    SYSTEM   -->|checkout request| PAYMONGO
    PAYMONGO -->|payment result / webhook| SYSTEM
    SYSTEM   -->|register / verify / login| AUTH
    AUTH     -->|JWT token / session| SYSTEM
```

---

## 3. DFD — Level 1: User Flows

All data flows triggered by the **User** role (regular account, buyer, scanner).

```mermaid
flowchart LR
    subgraph ACTORS["External Actors"]
        USER["User"]
        AUTH{{"Supabase Auth"}}
        PAYMONGO{{"PayMongo"}}
    end

    subgraph PROCESSES["Processes"]
        P1(("1.0\nRegister\nand Verify"))
        P2(("2.0\nLogin\nand Session"))
        P3(("3.0\nFace Scan\nand AI Makeup"))
        P4(("4.0\nSave\nFavorites"))
        P5(("5.0\nSubscribe\nto Plan"))
        P6(("6.0\nBrowse\nand Order"))
    end

    subgraph STORES["Data Stores"]
        DS_ACCOUNTS[("accounts")]
        DS_VERIFY[("verification_codes")]
        DS_SCANS[("scans")]
        DS_FAV[("favorites")]
        DS_PLANS[("subscription_plans")]
        DS_SUBS[("user_subscriptions")]
        DS_PRODUCTS[("products")]
        DS_ORDERS[("orders / order_items")]
        DS_PAY[("payment_sessions")]
    end

    USER        -->|email + password| P1
    P1          -->|register identity| AUTH
    AUTH        -->|user ID| P1
    P1          -->|store OTP| DS_VERIFY
    P1          -->|create account| DS_ACCOUNTS
    P1          -->|confirmed| USER

    USER        -->|credentials| P2
    P2          -->|verify session| AUTH
    AUTH        -->|JWT token| P2
    P2          -->|read profile| DS_ACCOUNTS
    P2          -->|session token| USER

    USER        -->|camera photo| P3
    P3          -->|save scan| DS_SCANS
    P3          -->|AI look result| USER

    USER        -->|tap save| P4
    P4          -->|write record| DS_FAV
    P4          -->|read list| DS_FAV
    P4          -->|favorites list| USER

    USER        -->|choose plan| P5
    P5          -->|read plans| DS_PLANS
    DS_PLANS    -->|plan details| P5
    P5          -->|initiate checkout| PAYMONGO
    PAYMONGO    -->|payment result| P5
    P5          -->|write subscription| DS_SUBS
    P5          -->|log session| DS_PAY
    P5          -->|subscription active| USER

    USER        -->|browse products| P6
    P6          -->|read listings| DS_PRODUCTS
    DS_PRODUCTS -->|product list| P6
    P6          -->|initiate checkout| PAYMONGO
    PAYMONGO    -->|payment result| P6
    P6          -->|create order| DS_ORDERS
    P6          -->|log session| DS_PAY
    P6          -->|order confirmation| USER
```

---

## 4. DFD — Level 1: Client Flows

All data flows triggered by the **Client** role (business account / seller).

```mermaid
flowchart LR
    subgraph ACTORS["External Actors"]
        CLIENT["Client\nBusiness"]
        ADMIN_NODE["Admin\napproval"]
    end

    subgraph PROCESSES["Processes"]
        P1(("1.0\nRegister\nBusiness"))
        P2(("2.0\nManage\nProducts"))
        P3(("3.0\nView Orders\nReceived"))
        P4(("4.0\nSales\nAnalytics"))
        P5(("5.0\nShop\nSettings"))
    end

    subgraph STORES["Data Stores"]
        DS_ACCOUNTS[("accounts")]
        DS_PRODUCTS[("products")]
        DS_ORDERS[("orders / order_items")]
        DS_AUDIT[("audit_logs")]
    end

    CLIENT      -->|business details| P1
    P1          -->|write business fields| DS_ACCOUNTS
    P1          -->|pending verification| ADMIN_NODE
    ADMIN_NODE  -->|business_verified = true| DS_ACCOUNTS
    P1          -->|account active| CLIENT

    CLIENT      -->|create / edit / delete| P2
    P2          -->|write products| DS_PRODUCTS
    P2          -->|read own products| DS_PRODUCTS
    DS_PRODUCTS -->|product list| P2
    P2          -->|listing confirmed| CLIENT

    DS_ORDERS   -->|new order event| P3
    P3          -->|read by business_id| DS_ORDERS
    P3          -->|order details| CLIENT

    CLIENT      -->|open dashboard| P4
    P4          -->|read orders| DS_ORDERS
    P4          -->|read products| DS_PRODUCTS
    P4          -->|sales summary| CLIENT

    CLIENT      -->|update profile / logo| P5
    P5          -->|update account| DS_ACCOUNTS
    P5          -->|log change| DS_AUDIT
    P5          -->|updated profile| CLIENT
```

---

## 5. DFD — Level 1: Admin Flows

All data flows triggered by the **Admin** role (platform operator).

```mermaid
flowchart LR
    ADMIN["Admin"]

    subgraph PROCESSES["Processes"]
        P1(("1.0\nManage Users\nand Roles"))
        P2(("2.0\nVerify Business\nAccounts"))
        P3(("3.0\nManage\nSubscription Plans"))
        P4(("4.0\nOversee Orders\nand Payments"))
        P5(("5.0\nPlatform\nAnalytics"))
        P6(("6.0\nAudit Log\nReview"))
    end

    subgraph STORES["Data Stores"]
        DS_ACCOUNTS[("accounts")]
        DS_PLANS[("subscription_plans")]
        DS_SUBS[("user_subscriptions")]
        DS_PRODUCTS[("products")]
        DS_ORDERS[("orders / order_items")]
        DS_PROFITS[("profits")]
        DS_AUDIT[("audit_logs")]
        DS_PAY[("payment_events")]
    end

    ADMIN       -->|view / ban / change role| P1
    P1          -->|read all accounts| DS_ACCOUNTS
    DS_ACCOUNTS -->|user list| P1
    P1          -->|update role| DS_ACCOUNTS
    P1          -->|log action| DS_AUDIT
    P1          -->|confirmation| ADMIN

    ADMIN       -->|approve / reject| P2
    P2          -->|read pending businesses| DS_ACCOUNTS
    DS_ACCOUNTS -->|pending list| P2
    P2          -->|set business_verified| DS_ACCOUNTS
    P2          -->|log action| DS_AUDIT
    P2          -->|verified status| ADMIN

    ADMIN       -->|create / edit / deactivate| P3
    P3          -->|write plans| DS_PLANS
    P3          -->|read subscriptions| DS_SUBS
    DS_SUBS     -->|subscriber counts| P3
    P3          -->|log action| DS_AUDIT
    P3          -->|plan saved| ADMIN

    ADMIN       -->|view orders / refunds| P4
    P4          -->|read all orders| DS_ORDERS
    DS_ORDERS   -->|order records| P4
    P4          -->|read payment events| DS_PAY
    DS_PAY      -->|webhook log| P4
    P4          -->|write profits| DS_PROFITS
    P4          -->|order report| ADMIN

    ADMIN       -->|open dashboard| P5
    P5          -->|read profits| DS_PROFITS
    P5          -->|read user counts| DS_ACCOUNTS
    P5          -->|read subscriptions| DS_SUBS
    P5          -->|read orders| DS_ORDERS
    P5          -->|platform KPIs| ADMIN

    ADMIN       -->|query audit trail| P6
    P6          -->|read logs| DS_AUDIT
    DS_AUDIT    -->|log entries| P6
    P6          -->|audit report| ADMIN
```

---

## 6. Role–Table Access Matrix

| Table | User read | User write | Client read | Client write | Admin read | Admin write |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| `accounts` | own only | own only | own only | own only | all | all |
| `verification_codes` | own only | own only | own only | own only | — | — |
| `scans` | own only | own only | — | — | all | — |
| `favorites` | own only | own only | — | — | — | — |
| `subscription_plans` | active only | — | active only | — | all | all |
| `user_subscriptions` | own only | — | — | — | all | all |
| `products` | active only | — | own only | own only | all | all |
| `orders` | own only | own only | own sales | — | all | all |
| `order_items` | own only | own only | own business | — | all | all |
| `payment_sessions` | own only | own only | — | — | all | all |
| `payment_events` | — | — | — | — | all | — |
| `profits` | — | — | — | — | all | all |
| `audit_logs` | — | — | — | — | all | all |
