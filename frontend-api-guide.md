# Frontend API Guide

Base URL: `https://rider-prod.mangaale.com/v1`

This guide is for frontend implementation against the rider backend. All protected endpoints require a bearer access token unless marked public.

## Quick setup

```bash
BASE_URL="https://rider-prod.mangaale.com/v1"
ACCESS_TOKEN="<access_token>"
REFRESH_TOKEN="<refresh_token>"
RIDER_REQUEST_ID="frontend-web-001"
```

Recommended headers for protected requests:

```bash
-H "Authorization: Bearer $ACCESS_TOKEN" \
-H "Content-Type: application/json" \
-H "X-Request-ID: $RIDER_REQUEST_ID"
```

## Standard response envelopes

Success:

```json
{
  "success": true,
  "message": "order accepted successfully",
  "data": {},
  "meta": {}
}
```

Error:

```json
{
  "success": false,
  "message": "request validation failed",
  "error_code": "VALIDATION_FAILED",
  "errors": {
    "login": "required",
    "password": "required"
  }
}
```

## Common HTTP status usage

- `200` success
- `201` resource created
- `400` invalid body, validation, OTP, bad query params
- `401` missing or invalid token, invalid credentials
- `403` role not allowed or business restriction
- `404` rider/order/user/ticket/assignment/otp not found
- `409` state conflict such as invalid order transition or insufficient balance
- `429` rate limit or OTP lock/resend limit
- `500` internal server error

## Frontend auth notes

- All `/v1/auth/*` endpoints are rate limited to 20 requests per minute per IP.
- Access token goes in `Authorization: Bearer <token>`.
- Refresh token is sent in JSON body to `/auth/refresh-token`.
- `X-Request-ID` is optional but useful for tracing support issues.
- Validation errors use lowercase field names and validator tags like `required`, `email`, `numeric`, `min`, `url`.

## Auth APIs

### POST /auth/rider/login

```bash
curl -X POST "$BASE_URL/auth/rider/login" \
  -H "Content-Type: application/json" \
  -d '{
    "login": "rider@example.com",
    "password": "Rider@123",
    "device_id": "android-rider-001",
    "device_name": "Samsung S24"
  }'
```

Success `200`:

```json
{
  "success": true,
  "message": "login successful",
  "data": {
    "user": {
      "id": "usr_rider_001",
      "first_name": "Ravi",
      "last_name": "Kumar",
      "email": "rider@example.com",
      "phone": "+919999999999",
      "status": "ACTIVE",
      "roles": ["RIDER"],
      "primary_role": "RIDER",
      "photo_url": "https://cdn.example.com/riders/ravi.jpg",
      "email_verified": true,
      "phone_verified": true,
      "created_at": "2026-03-16T09:00:00Z",
      "updated_at": "2026-03-16T09:00:00Z"
    },
    "rider": {
      "id": "rdr_001",
      "user_id": "usr_rider_001",
      "status": "ACTIVE",
      "availability_status": "OFFLINE",
      "kyc_status": "APPROVED",
      "approval_status": "APPROVED",
      "vehicle_type": "BIKE",
      "vehicle_number": "MH12AB1234",
      "avg_rating": 4.8,
      "rating_count": 128,
      "acceptance_rate": 92.3,
      "completion_rate": 95.6,
      "cancellation_rate": 1.4,
      "rejection_rate": 4.1,
      "active_hours_today": 0,
      "created_at": "2026-03-16T09:00:00Z",
      "updated_at": "2026-03-16T09:00:00Z"
    },
    "tokens": {
      "access_token": "<jwt_access_token>",
      "refresh_token": "<refresh_token>",
      "expires_in": 3600,
      "token_type": "Bearer"
    }
  }
}
```

Common errors:

```json
{
  "success": false,
  "message": "invalid credentials",
  "error_code": "UNAUTHORIZED"
}
```

```json
{
  "success": false,
  "message": "request validation failed",
  "error_code": "VALIDATION_FAILED",
  "errors": {
    "deviceid": "required",
    "devicename": "required"
  }
}
```

### POST /auth/rider/otp/send

```bash
curl -X POST "$BASE_URL/auth/rider/otp/send" \
  -H "Content-Type: application/json" \
  -d '{
    "login": "rider@example.com"
  }'
```

Success `200`:

```json
{
  "success": true,
  "message": "otp sent successfully",
  "data": {
    "expires_in_seconds": 300,
    "channel": "SMS"
  }
}
```

Common errors:

```json
{
  "success": false,
  "message": "user not found",
  "error_code": "USER_NOT_FOUND"
}
```

### POST /auth/rider/otp/verify

```bash
curl -X POST "$BASE_URL/auth/rider/otp/verify" \
  -H "Content-Type: application/json" \
  -d '{
    "login": "rider@example.com",
    "otp": "123456",
    "device_id": "android-rider-001",
    "device_name": "Samsung S24"
  }'
```

Success `200`: same payload shape as login.

Common errors:

```json
{
  "success": false,
  "message": "invalid otp",
  "error_code": "INVALID_OTP"
}
```

```json
{
  "success": false,
  "message": "otp expired",
  "error_code": "OTP_EXPIRED"
}
```

```json
{
  "success": false,
  "message": "otp retry limit exceeded",
  "error_code": "OTP_LOCKED"
}
```

### POST /auth/refresh-token

```bash
curl -X POST "$BASE_URL/auth/refresh-token" \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "'$REFRESH_TOKEN'",
    "device_id": "android-rider-001"
  }'
```

Success `200`:

```json
{
  "success": true,
  "message": "token refreshed successfully",
  "data": {
    "access_token": "<new_jwt_access_token>",
    "refresh_token": "<same_refresh_token>",
    "expires_in": 3600,
    "token_type": "Bearer"
  }
}
```

Common errors:

```json
{
  "success": false,
  "message": "invalid refresh token",
  "error_code": "UNAUTHORIZED"
}
```

```json
{
  "success": false,
  "message": "refresh token does not belong to this device",
  "error_code": "FORBIDDEN"
}
```

### POST /auth/logout

```bash
curl -X POST "$BASE_URL/auth/logout" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "'$REFRESH_TOKEN'"
  }'
```

Success `200`:

```json
{
  "success": true,
  "message": "logout successful",
  "data": {
    "logged_out": true
  }
}
```

### POST /auth/logout-all

```bash
curl -X POST "$BASE_URL/auth/logout-all" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "logged out from all devices",
  "data": {
    "logged_out_all": true
  }
}
```

### POST /auth/forgot-password

```bash
curl -X POST "$BASE_URL/auth/forgot-password" \
  -H "Content-Type: application/json" \
  -d '{
    "login": "rider@example.com"
  }'
```

Success `200`:

```json
{
  "success": true,
  "message": "password reset otp sent",
  "data": {
    "expires_in_seconds": 300,
    "channel": "SMS"
  }
}
```

### POST /auth/reset-password

```bash
curl -X POST "$BASE_URL/auth/reset-password" \
  -H "Content-Type: application/json" \
  -d '{
    "login": "rider@example.com",
    "otp": "123456",
    "new_password": "NewStrong@123"
  }'
```

Success `200`:

```json
{
  "success": true,
  "message": "password reset successful",
  "data": {
    "reset": true
  }
}
```

Common errors:

```json
{
  "success": false,
  "message": "invalid or expired otp",
  "error_code": "INVALID_OTP"
}
```

### GET /auth/me

```bash
curl "$BASE_URL/auth/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "profile fetched successfully",
  "data": {
    "user": {
      "id": "usr_rider_001",
      "first_name": "Ravi",
      "last_name": "Kumar",
      "email": "rider@example.com",
      "phone": "+919999999999",
      "roles": ["RIDER"],
      "primary_role": "RIDER",
      "status": "ACTIVE"
    },
    "rider": {
      "id": "rdr_001",
      "availability_status": "OFFLINE",
      "kyc_status": "APPROVED",
      "approval_status": "APPROVED"
    }
  }
}
```

## Rider Profile APIs

All endpoints below require role `RIDER`.

### GET /riders/me

```bash
curl "$BASE_URL/riders/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "rider profile fetched successfully",
  "data": {
    "user": {
      "id": "usr_rider_001",
      "first_name": "Ravi",
      "last_name": "Kumar",
      "email": "rider@example.com",
      "phone": "+919999999999",
      "photo_url": "https://cdn.example.com/riders/ravi.jpg",
      "status": "ACTIVE"
    },
    "rider": {
      "id": "rdr_001",
      "user_id": "usr_rider_001",
      "status": "ACTIVE",
      "availability_status": "OFFLINE",
      "kyc_status": "APPROVED",
      "approval_status": "APPROVED",
      "vehicle_type": "BIKE",
      "vehicle_number": "MH12AB1234",
      "avg_rating": 4.8,
      "rating_count": 128
    },
    "vehicle": {
      "id": "veh_001",
      "rider_id": "rdr_001",
      "vehicle_type": "BIKE",
      "registration_no": "MH12AB1234",
      "color": "Red",
      "capacity": 25,
      "insurance_expiry": "2026-09-16T00:00:00Z"
    },
    "bank_account": {
      "id": "bank_001",
      "rider_id": "rdr_001",
      "account_holder": "Ravi Kumar",
      "bank_name": "State Bank of India",
      "account_number": "XXXXXX9012",
      "ifsc_code": "SBIN0000456",
      "is_verified": true
    },
    "documents": [
      {
        "id": "doc_001",
        "document_type": "DRIVING_LICENSE",
        "document_url": "https://cdn.example.com/docs/dl.jpg",
        "status": "APPROVED"
      }
    ]
  }
}
```

### PUT /riders/me

```bash
curl -X PUT "$BASE_URL/riders/me" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Ravi",
    "last_name": "Kumar",
    "email": "ravi.kumar@example.com",
    "phone": "+919876543210"
  }'
```

Success `200`: returns updated `user` object.

Common errors:

```json
{
  "success": false,
  "message": "request validation failed",
  "error_code": "VALIDATION_FAILED",
  "errors": {
    "email": "email"
  }
}
```

### PUT /riders/me/photo

```bash
curl -X PUT "$BASE_URL/riders/me/photo" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "photo_url": "https://cdn.example.com/riders/ravi-new.jpg"
  }'
```

Success `200`: returns updated `user` object with new `photo_url`.

### PUT /riders/me/vehicle

```bash
curl -X PUT "$BASE_URL/riders/me/vehicle" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "vehicle_type": "SCOOTER",
    "registration_no": "MH14XY4567",
    "color": "Black",
    "capacity": 30,
    "insurance_expiry": "2026-12-31"
  }'
```

Success `200`: returns updated vehicle object.

Common errors:

```json
{
  "success": false,
  "message": "insurance_expiry must be YYYY-MM-DD",
  "error_code": "INVALID_DATE"
}
```

### PUT /riders/me/documents

```bash
curl -X PUT "$BASE_URL/riders/me/documents" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "documents": [
      {
        "document_type": "DRIVING_LICENSE",
        "document_url": "https://cdn.example.com/docs/new-license.jpg"
      },
      {
        "document_type": "AADHAAR",
        "document_url": "https://cdn.example.com/docs/new-aadhaar.jpg"
      }
    ]
  }'
```

Success `200`:

```json
{
  "success": true,
  "message": "documents updated successfully",
  "data": [
    {
      "id": "doc_xxx",
      "rider_id": "rdr_001",
      "document_type": "DRIVING_LICENSE",
      "document_url": "https://cdn.example.com/docs/new-license.jpg",
      "status": "PENDING_REVIEW",
      "uploaded_at": "2026-03-16T10:30:00Z"
    }
  ]
}
```

### GET /riders/me/documents

```bash
curl "$BASE_URL/riders/me/documents" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns array of `rider_documents` and `meta.count`.

### PUT /riders/me/bank-account

```bash
curl -X PUT "$BASE_URL/riders/me/bank-account" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "account_holder": "Ravi Kumar",
    "bank_name": "HDFC Bank",
    "account_number": "123456789012",
    "ifsc_code": "HDFC0001234",
    "upi_id": "ravi@hdfcbank"
  }'
```

Success `200`: returns bank account object.

### GET /riders/me/status

```bash
curl "$BASE_URL/riders/me/status" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "rider status fetched successfully",
  "data": {
    "status": "ACTIVE",
    "availability_status": "OFFLINE",
    "kyc_status": "APPROVED",
    "approval_status": "APPROVED",
    "active_shift": null
  }
}
```

## Availability and Shift APIs

### POST /riders/me/go-online

```bash
curl -X POST "$BASE_URL/riders/me/go-online" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "X-Request-ID: $RIDER_REQUEST_ID"
```

Success `200`:

```json
{
  "success": true,
  "message": "rider is online",
  "data": {
    "rider": {
      "id": "rdr_001",
      "availability_status": "ONLINE",
      "status": "ACTIVE"
    },
    "shift": {
      "id": "shf_001",
      "rider_id": "rdr_001",
      "status": "ACTIVE",
      "started_at": "2026-03-16T10:35:00Z",
      "started_by": "usr_rider_001"
    },
    "available_for_assignment": true
  }
}
```

Common errors:

```json
{
  "success": false,
  "message": "rider is not eligible to go online",
  "error_code": "FORBIDDEN"
}
```

```json
{
  "success": false,
  "message": "an active shift is required",
  "error_code": "SHIFT_REQUIRED"
}
```

### POST /riders/me/go-offline

```bash
curl -X POST "$BASE_URL/riders/me/go-offline" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "X-Request-ID: $RIDER_REQUEST_ID"
```

Success `200`: returns updated rider and `available_for_assignment: false`.

### POST /riders/me/break/start

```bash
curl -X POST "$BASE_URL/riders/me/break/start" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "tea break"
  }'
```

Success `200`: returns `rider_break` object.

Common errors:

```json
{
  "success": false,
  "message": "active shift required",
  "error_code": "SHIFT_REQUIRED"
}
```

### POST /riders/me/break/end

```bash
curl -X POST "$BASE_URL/riders/me/break/end" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns ended `rider_break` object.

Common errors:

```json
{
  "success": false,
  "message": "break not found",
  "error_code": "NO_ACTIVE_BREAK"
}
```

### POST /riders/me/shift/start

```bash
curl -X POST "$BASE_URL/riders/me/shift/start" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns created `rider_shift` object.

Common errors:

```json
{
  "success": false,
  "message": "active shift already exists",
  "error_code": "SHIFT_ALREADY_ACTIVE"
}
```

### POST /riders/me/shift/end

```bash
curl -X POST "$BASE_URL/riders/me/shift/end" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns ended `rider_shift` and rider is forced offline.

Common errors:

```json
{
  "success": false,
  "message": "shift not found",
  "error_code": "NO_ACTIVE_SHIFT"
}
```

### GET /riders/me/shift/today

```bash
curl "$BASE_URL/riders/me/shift/today" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns array of today's shift records plus pagination `meta`.

### GET /riders/me/shift/history

```bash
curl "$BASE_URL/riders/me/shift/history" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns array of all rider shift records plus pagination `meta`.

## Order Request, Assignment, and Delivery APIs

### GET /riders/me/order-requests

```bash
curl "$BASE_URL/riders/me/order-requests" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "order requests fetched successfully",
  "data": [
    {
      "assignment": {
        "id": "asg_001",
        "order_id": "ord_001",
        "rider_id": "rdr_001",
        "restaurant_id": "rest_mg_001",
        "status": "OFFERED",
        "assigned_by": "usr_dispatch_001",
        "assigned_at": "2026-03-16T10:20:00Z",
        "decision_deadline_at": "2026-03-16T10:20:45Z"
      },
      "order": {
        "id": "ord_001",
        "order_number": "ORD-1001",
        "restaurant_id": "rest_mg_001",
        "customer_name": "Ananya Singh",
        "customer_phone": "+919876543210",
        "delivery_address": "Baner Road, Pune",
        "delivery_latitude": 18.559,
        "delivery_longitude": 73.786,
        "status": "ASSIGNED",
        "distance_km": 5.8,
        "base_payout": 40,
        "distance_payout": 26,
        "waiting_charges": 0,
        "surge_bonus": 10,
        "tip_amount": 15,
        "total_amount": 780,
        "pickup_otp_required": true,
        "delivery_otp_required": true
      },
      "items": [
        {
          "id": "itm_001",
          "order_id": "ord_001",
          "name": "Paneer Bowl",
          "quantity": 2,
          "unit_price": 220
        }
      ]
    }
  ],
  "meta": {
    "page": 1,
    "page_size": 1,
    "total": 1
  }
}
```

### GET /riders/me/order-requests/{id}

```bash
curl "$BASE_URL/riders/me/order-requests/asg_001" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns one `assignment + order + items` object.

Common errors:

```json
{
  "success": false,
  "message": "order request not found",
  "error_code": "ASSIGNMENT_NOT_FOUND"
}
```

### POST /riders/me/order-requests/{id}/accept

```bash
curl -X POST "$BASE_URL/riders/me/order-requests/asg_001/accept" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "X-Request-ID: $RIDER_REQUEST_ID"
```

Success `200`: returns `assignment + order + items` with assignment `status: ACCEPTED` and order `status: ACCEPTED`.

Common errors:

```json
{
  "success": false,
  "message": "order request expired",
  "error_code": "ORDER_REQUEST_EXPIRED"
}
```

```json
{
  "success": false,
  "message": "active shift required to accept order",
  "error_code": "SHIFT_REQUIRED"
}
```

### POST /riders/me/order-requests/{id}/reject

```bash
curl -X POST "$BASE_URL/riders/me/order-requests/asg_001/reject" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -H "X-Request-ID: $RIDER_REQUEST_ID" \
  -d '{
    "reason": "too far from restaurant"
  }'
```

Success `200`:

```json
{
  "success": true,
  "message": "order rejected successfully",
  "data": {
    "id": "asg_001",
    "order_id": "ord_001",
    "rider_id": "rdr_001",
    "status": "REJECTED",
    "reject_reason": "too far from restaurant"
  }
}
```

### GET /riders/me/active-order

```bash
curl "$BASE_URL/riders/me/active-order" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns `{assignment, order, items}`.

Common errors:

```json
{
  "success": false,
  "message": "active order not found",
  "error_code": "ACTIVE_ORDER_NOT_FOUND"
}
```

### GET /riders/me/orders/assigned

```bash
curl "$BASE_URL/riders/me/orders/assigned" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns list of currently assigned or in-progress orders plus pagination `meta`.

### GET /riders/me/orders/history

```bash
curl "$BASE_URL/riders/me/orders/history" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns delivered order history plus pagination `meta`.

### GET /riders/me/orders/{orderId}

```bash
curl "$BASE_URL/riders/me/orders/ord_001" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns `{assignment, order, items}` for that rider's order.

### POST /riders/me/orders/{orderId}/arrived-at-restaurant

```bash
curl -X POST "$BASE_URL/riders/me/orders/ord_001/arrived-at-restaurant" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns updated order with `status: REACHED_RESTAURANT`.

### POST /riders/me/orders/{orderId}/picked-up

```bash
curl -X POST "$BASE_URL/riders/me/orders/ord_001/picked-up" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns updated order with `status: PICKED_UP`.

Common errors:

```json
{
  "success": false,
  "message": "pickup otp verification required before pickup",
  "error_code": "PICKUP_OTP_REQUIRED"
}
```

### POST /riders/me/orders/{orderId}/start-delivery

```bash
curl -X POST "$BASE_URL/riders/me/orders/ord_001/start-delivery" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns updated order with `status: ON_THE_WAY`.

### POST /riders/me/orders/{orderId}/arrived-at-customer

```bash
curl -X POST "$BASE_URL/riders/me/orders/ord_001/arrived-at-customer" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns updated order with `status: REACHED_CUSTOMER`.

### POST /riders/me/orders/{orderId}/deliver

```bash
curl -X POST "$BASE_URL/riders/me/orders/ord_001/deliver" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns updated order with `status: DELIVERED` and `delivered_at`.

Common errors:

```json
{
  "success": false,
  "message": "delivery otp verification required before completing order",
  "error_code": "DELIVERY_OTP_REQUIRED"
}
```

### POST /riders/me/orders/{orderId}/failed

```bash
curl -X POST "$BASE_URL/riders/me/orders/ord_001/failed" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "customer unreachable"
  }'
```

Success `200`: returns updated order with `status: FAILED`.

### POST /riders/me/orders/{orderId}/cancel-request

```bash
curl -X POST "$BASE_URL/riders/me/orders/ord_001/cancel-request" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "restaurant marked order unavailable"
  }'
```

Success `200`:

```json
{
  "success": true,
  "message": "cancel request submitted",
  "data": {
    "order_id": "ord_001",
    "requested": true,
    "reason": "restaurant marked order unavailable"
  }
}
```

### GET /riders/me/orders/{orderId}/timeline

```bash
curl "$BASE_URL/riders/me/orders/ord_001/timeline" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "order timeline fetched successfully",
  "data": [
    {
      "id": "hst_001",
      "order_id": "ord_001",
      "assignment_id": "asg_001",
      "status": "ASSIGNED",
      "actor_id": "usr_dispatch_001",
      "actor_role": "DISPATCHER_MANAGER",
      "comment": "Order assigned to rider queue",
      "created_at": "2026-03-16T10:20:00Z"
    },
    {
      "id": "hst_002",
      "order_id": "ord_001",
      "assignment_id": "asg_001",
      "status": "ACCEPTED",
      "actor_id": "usr_rider_001",
      "actor_role": "RIDER",
      "comment": "Rider accepted order request",
      "created_at": "2026-03-16T10:21:00Z"
    }
  ],
  "meta": {
    "count": 2
  }
}
```

Common transition error used by multiple lifecycle endpoints:

```json
{
  "success": false,
  "message": "cannot move order from ASSIGNED to ON_THE_WAY",
  "error_code": "INVALID_ORDER_TRANSITION"
}
```

## OTP and Verification APIs

### POST /riders/me/orders/{orderId}/verify-pickup-otp

```bash
curl -X POST "$BASE_URL/riders/me/orders/ord_001/verify-pickup-otp" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "otp": "123456"
  }'
```

Success `200`: returns updated order with `status: PICKUP_VERIFIED`.

### POST /riders/me/orders/{orderId}/verify-delivery-otp

```bash
curl -X POST "$BASE_URL/riders/me/orders/ord_001/verify-delivery-otp" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "otp": "654321"
  }'
```

Success `200`: returns updated order with `status: DELIVERY_VERIFIED`.

Common OTP errors for both endpoints:

```json
{
  "success": false,
  "message": "otp not found",
  "error_code": "OTP_NOT_FOUND"
}
```

```json
{
  "success": false,
  "message": "otp expired",
  "error_code": "OTP_EXPIRED"
}
```

```json
{
  "success": false,
  "message": "invalid otp",
  "error_code": "INVALID_OTP"
}
```

### POST /orders/{orderId}/resend-delivery-otp

Role required: `DISPATCHER_MANAGER`, `RESTAURANT_ADMIN`, `RESTAURANT_OWNER`, or `SUPER_ADMIN`.

```bash
curl -X POST "$BASE_URL/orders/ord_001/resend-delivery-otp" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "delivery otp resent successfully",
  "data": {
    "order_id": "ord_001",
    "purpose": "DELIVERY",
    "expires_in_seconds": 300
  }
}
```

### POST /orders/{orderId}/resend-pickup-otp

```bash
curl -X POST "$BASE_URL/orders/ord_001/resend-pickup-otp" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: same payload shape with `purpose: PICKUP`.

Common resend errors:

```json
{
  "success": false,
  "message": "otp resend limit reached",
  "error_code": "OTP_RESEND_LIMIT_REACHED"
}
```

```json
{
  "success": false,
  "message": "insufficient permissions",
  "error_code": "FORBIDDEN"
}
```

## Live Location APIs

### POST /riders/me/location/update

```bash
curl -X POST "$BASE_URL/riders/me/location/update" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "order_id": "ord_001",
    "latitude": 18.5591,
    "longitude": 73.7862,
    "accuracy_meters": 8,
    "speed_kph": 32,
    "heading_degrees": 115,
    "battery_level": 78,
    "source": "gps"
  }'
```

Success `200`:

```json
{
  "success": true,
  "message": "location updated successfully",
  "data": {
    "rider_id": "rdr_001",
    "order_id": "ord_001",
    "latitude": 18.5591,
    "longitude": 73.7862,
    "accuracy_meters": 8,
    "speed_kph": 32,
    "heading_degrees": 115,
    "battery_level": 78,
    "source": "gps",
    "recorded_at": "2026-03-16T10:40:00Z"
  }
}
```

### POST /riders/me/location/bulk-update

```bash
curl -X POST "$BASE_URL/riders/me/location/bulk-update" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "points": [
      {
        "order_id": "ord_001",
        "latitude": 18.5591,
        "longitude": 73.7862,
        "source": "gps"
      },
      {
        "order_id": "ord_001",
        "latitude": 18.5602,
        "longitude": 73.7870,
        "source": "gps"
      }
    ]
  }'
```

Success `200`: returns array of stored location points and `meta.count`.

### GET /riders/me/location/latest

```bash
curl "$BASE_URL/riders/me/location/latest" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns latest location object.

### GET /orders/{orderId}/tracking

```bash
curl "$BASE_URL/orders/ord_001/tracking" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "order tracking fetched successfully",
  "data": {
    "order": {
      "id": "ord_001",
      "order_number": "ORD-1001",
      "status": "ON_THE_WAY"
    },
    "assignment": {
      "id": "asg_001",
      "rider_id": "rdr_001",
      "status": "ACCEPTED"
    },
    "latest_location": {
      "rider_id": "rdr_001",
      "latitude": 18.5602,
      "longitude": 73.7870,
      "source": "gps",
      "recorded_at": "2026-03-16T10:42:00Z"
    },
    "timeline": [
      {
        "status": "ASSIGNED",
        "actor_role": "DISPATCHER_MANAGER",
        "created_at": "2026-03-16T10:20:00Z"
      },
      {
        "status": "ON_THE_WAY",
        "actor_role": "RIDER",
        "created_at": "2026-03-16T10:41:00Z"
      }
    ]
  }
}
```

### GET /riders/me/routes/{orderId}

```bash
curl "$BASE_URL/riders/me/routes/ord_001" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns array of location log points and `meta.count`.

Frontend note: current implementation ignores `orderId` and returns rider route history overall, so filter client-side by `order_id` if needed until backend narrows this endpoint.

## Earnings, Wallet, Payout APIs

### GET /riders/me/earnings/today

```bash
curl "$BASE_URL/riders/me/earnings/today" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### GET /riders/me/earnings/weekly

```bash
curl "$BASE_URL/riders/me/earnings/weekly" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

### GET /riders/me/earnings/monthly

```bash
curl "$BASE_URL/riders/me/earnings/monthly" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success shape for all three `200`:

```json
{
  "success": true,
  "message": "weekly earnings fetched successfully",
  "data": {
    "total": 93,
    "count": 1,
    "records": [
      {
        "id": "earn_001",
        "rider_id": "rdr_001",
        "order_id": "ord_002",
        "base_payout": 40,
        "distance_payout": 18,
        "waiting_charges": 5,
        "surge_bonus": 0,
        "tip_amount": 20,
        "incentive_amount": 10,
        "penalty_amount": 0,
        "cancellation_compensation": 0,
        "net_earning": 93,
        "created_at": "2026-03-15T05:00:00Z"
      }
    ]
  }
}
```

### GET /riders/me/earnings/summary

```bash
curl "$BASE_URL/riders/me/earnings/summary" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "earnings summary fetched successfully",
  "data": {
    "wallet": {
      "id": "wal_001",
      "rider_id": "rdr_001",
      "balance": 1240,
      "hold_balance": 0,
      "currency": "INR"
    },
    "weekly_total": 93,
    "monthly_total": 93,
    "acceptance_rate": 92.3,
    "completion_rate": 95.6
  }
}
```

### GET /riders/me/earnings/history

```bash
curl "$BASE_URL/riders/me/earnings/history" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns array of rider earnings and pagination `meta`.

### GET /riders/me/incentives

```bash
curl "$BASE_URL/riders/me/incentives" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns only earning records where `incentive_amount > 0`.

### GET /riders/me/bonus-history

```bash
curl "$BASE_URL/riders/me/bonus-history" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: same shape as incentives.

### GET /riders/me/wallet

```bash
curl "$BASE_URL/riders/me/wallet" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "wallet fetched successfully",
  "data": {
    "id": "wal_001",
    "rider_id": "rdr_001",
    "balance": 1240,
    "hold_balance": 0,
    "currency": "INR",
    "updated_at": "2026-03-16T10:00:00Z"
  }
}
```

### GET /riders/me/wallet/transactions

```bash
curl "$BASE_URL/riders/me/wallet/transactions" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "wallet transactions fetched successfully",
  "data": [
    {
      "id": "wtx_001",
      "wallet_id": "wal_001",
      "rider_id": "rdr_001",
      "type": "CREDIT",
      "amount": 93,
      "reference_id": "ord_002",
      "reference_type": "ORDER",
      "description": "Wallet credit for delivery ORD-1002",
      "created_at": "2026-03-15T05:10:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "page_size": 1,
    "total": 1
  }
}
```

### GET /riders/me/payouts

```bash
curl "$BASE_URL/riders/me/payouts" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns payout request list and pagination `meta`.

### GET /riders/me/payouts/{id}

```bash
curl "$BASE_URL/riders/me/payouts/pay_001" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "payout fetched successfully",
  "data": {
    "id": "pay_001",
    "rider_id": "rdr_001",
    "wallet_id": "wal_001",
    "amount": 750,
    "status": "PAID",
    "requested_at": "2026-03-09T08:00:00Z",
    "reviewed_at": "2026-03-10T08:00:00Z",
    "reviewed_by": "usr_admin_001"
  }
}
```

### POST /riders/me/payouts/request

```bash
curl -X POST "$BASE_URL/riders/me/payouts/request" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 600
  }'
```

Success `200`: returns created `payout_request` with `status: PENDING`.

Common errors:

```json
{
  "success": false,
  "message": "requested payout is below minimum threshold",
  "error_code": "PAYOUT_BELOW_MINIMUM"
}
```

```json
{
  "success": false,
  "message": "insufficient wallet balance",
  "error_code": "INSUFFICIENT_BALANCE"
}
```

### GET /riders/me/bank-account

```bash
curl "$BASE_URL/riders/me/bank-account" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns bank account object.

## Ratings and Performance APIs

### GET /riders/me/ratings/summary

```bash
curl "$BASE_URL/riders/me/ratings/summary" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "ratings summary fetched successfully",
  "data": {
    "average_rating": 4.8,
    "rating_count": 128,
    "customer_reviews": 1,
    "restaurant_reviews": 1
  }
}
```

### GET /riders/me/reviews

```bash
curl "$BASE_URL/riders/me/reviews" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns list of `ratings_reviews` plus pagination `meta`.

### GET /riders/me/performance-score

```bash
curl "$BASE_URL/riders/me/performance-score" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "performance score fetched successfully",
  "data": {
    "score": 94.98,
    "acceptance_rate": 92.3,
    "completion_rate": 95.6,
    "rating_average": 4.8
  }
}
```

## Notification APIs

### GET /riders/me/notifications

```bash
curl "$BASE_URL/riders/me/notifications" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "notifications fetched successfully",
  "data": [
    {
      "id": "ntf_001",
      "user_id": "usr_rider_001",
      "type": "ORDER_REQUEST",
      "title": "New delivery request",
      "body": "Order ORD-1001 is waiting for your response",
      "status": "UNREAD",
      "channel": "PUSH",
      "order_id": "ord_001",
      "created_at": "2026-03-16T10:18:00Z"
    }
  ],
  "meta": {
    "page": 1,
    "page_size": 1,
    "total": 1
  }
}
```

### PUT /riders/me/notifications/{id}/read

```bash
curl -X PUT "$BASE_URL/riders/me/notifications/ntf_001/read" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "notification marked as read",
  "data": {
    "updated": true
  }
}
```

### PUT /riders/me/notifications/read-all

```bash
curl -X PUT "$BASE_URL/riders/me/notifications/read-all" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns `{ "updated": true }`.

### POST /riders/me/device-token

```bash
curl -X POST "$BASE_URL/riders/me/device-token" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "android-rider-001",
    "platform": "android",
    "token": "fcm-token-value"
  }'
```

Success `200`: returns saved device token object.

### DELETE /riders/me/device-token

```bash
curl -X DELETE "$BASE_URL/riders/me/device-token?device_id=android-rider-001" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "device token deleted successfully",
  "data": {
    "deleted": true
  }
}
```

Common errors:

```json
{
  "success": false,
  "message": "device_id query param is required",
  "error_code": "DEVICE_ID_REQUIRED"
}
```

## Support APIs

### POST /riders/me/support-tickets

```bash
curl -X POST "$BASE_URL/riders/me/support-tickets" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "subject": "Customer not reachable",
    "category": "DELIVERY_ISSUE",
    "priority": "HIGH",
    "order_id": "ord_001",
    "description": "Customer phone is switched off and building gate is locked."
  }'
```

Success `201`:

```json
{
  "success": true,
  "message": "support ticket created successfully",
  "data": {
    "id": "sup_001",
    "rider_id": "rdr_001",
    "subject": "Customer not reachable",
    "category": "DELIVERY_ISSUE",
    "priority": "HIGH",
    "status": "OPEN",
    "order_id": "ord_001",
    "description": "Customer phone is switched off and building gate is locked.",
    "created_at": "2026-03-16T10:50:00Z",
    "updated_at": "2026-03-16T10:50:00Z"
  }
}
```

### GET /riders/me/support-tickets

```bash
curl "$BASE_URL/riders/me/support-tickets" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns support ticket list and pagination `meta`.

### GET /riders/me/support-tickets/{id}

```bash
curl "$BASE_URL/riders/me/support-tickets/sup_001" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "support ticket fetched successfully",
  "data": {
    "ticket": {
      "id": "sup_001",
      "status": "OPEN",
      "subject": "Customer not reachable"
    },
    "messages": [
      {
        "id": "msg_001",
        "ticket_id": "sup_001",
        "actor_id": "usr_rider_001",
        "actor_role": "RIDER",
        "message": "Customer phone is switched off and building gate is locked.",
        "created_at": "2026-03-16T10:50:00Z"
      }
    ]
  }
}
```

### POST /riders/me/support-tickets/{id}/reply

```bash
curl -X POST "$BASE_URL/riders/me/support-tickets/sup_001/reply" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Please call the restaurant manager as well."
  }'
```

Success `200`: returns `{ticket, latest_message, messages}`.

Common ticket error:

```json
{
  "success": false,
  "message": "ticket not found",
  "error_code": "TICKET_NOT_FOUND"
}
```

## Admin and Dispatcher APIs

These endpoints require one of: `SUPER_ADMIN`, `RESTAURANT_OWNER`, `RESTAURANT_ADMIN`, `DISPATCHER_MANAGER`.

### GET /admin/riders

```bash
curl "$BASE_URL/admin/riders" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns list of `{user, rider}` records with pagination `meta`.

### GET /admin/riders/{id}

```bash
curl "$BASE_URL/admin/riders/rdr_001" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns `{user, rider, vehicle, bank_account, documents}`.

### POST /admin/riders

```bash
curl -X POST "$BASE_URL/admin/riders" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Aman",
    "last_name": "Verma",
    "email": "aman.verma@example.com",
    "phone": "+919811112222",
    "password": "StrongPass@123",
    "restaurant_id": "rest_mg_001"
  }'
```

Success `201`:

```json
{
  "success": true,
  "message": "rider created successfully",
  "data": {
    "user": {
      "id": "usr_xxx",
      "first_name": "Aman",
      "last_name": "Verma",
      "email": "aman.verma@example.com",
      "phone": "+919811112222",
      "roles": ["RIDER"],
      "primary_role": "RIDER",
      "status": "ACTIVE"
    },
    "rider": {
      "id": "rdr_xxx",
      "user_id": "usr_xxx",
      "status": "ACTIVE",
      "availability_status": "OFFLINE",
      "kyc_status": "PENDING",
      "approval_status": "PENDING"
    }
  }
}
```

### PUT /admin/riders/{id}

```bash
curl -X PUT "$BASE_URL/admin/riders/rdr_001" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Ravi",
    "last_name": "Kumar",
    "email": "ravi.kumar@example.com",
    "phone": "+919876543210"
  }'
```

Success `200`: returns `{user, rider}`.

### PUT /admin/riders/{id}/status

```bash
curl -X PUT "$BASE_URL/admin/riders/rdr_001/status" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "SUSPENDED"
  }'
```

Success `200`: returns updated rider object.

### GET /admin/orders/unassigned

```bash
curl "$BASE_URL/admin/orders/unassigned" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns order list with `status: READY_FOR_ASSIGNMENT`.

### POST /admin/orders/{orderId}/assign-rider

```bash
curl -X POST "$BASE_URL/admin/orders/ord_010/assign-rider" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "rider_id": "rdr_001"
  }'
```

Success `200`: returns created delivery assignment with `status: OFFERED`.

### POST /admin/orders/{orderId}/reassign-rider

```bash
curl -X POST "$BASE_URL/admin/orders/ord_010/reassign-rider" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "rider_id": "rdr_002"
  }'
```

Success `200`: returns new delivery assignment with `status: OFFERED`.

### GET /admin/orders/live

```bash
curl "$BASE_URL/admin/orders/live" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns list of orders in active delivery states.

### GET /admin/riders/live-status

```bash
curl "$BASE_URL/admin/riders/live-status" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns array of `{user, rider, active_shift, active_assignment}` and pagination `meta`.

### GET /admin/analytics/riders

```bash
curl "$BASE_URL/admin/analytics/riders" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "rider analytics fetched successfully",
  "data": {
    "rider_count": 1,
    "avg_acceptance_rate": 92.3,
    "avg_completion_rate": 95.6,
    "avg_cancellation_rate": 1.4,
    "avg_rating": 4.8,
    "live_orders": 1
  }
}
```

### GET /admin/config

```bash
curl "$BASE_URL/admin/config" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`:

```json
{
  "success": true,
  "message": "system config fetched successfully",
  "data": {
    "order_accept_timeout_seconds": 45,
    "pickup_otp_required": true,
    "delivery_otp_required": true,
    "otp_max_retries": 5,
    "otp_max_resends": 3,
    "rider_max_active_orders": 1,
    "surge_multiplier_default": 1,
    "minimum_payout_amount": 500
  }
}
```

### PUT /admin/config

```bash
curl -X PUT "$BASE_URL/admin/config" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "order_accept_timeout_seconds": 60,
    "pickup_otp_required": true,
    "delivery_otp_required": true,
    "rider_max_active_orders": 2,
    "otp_max_retries": 5,
    "otp_max_resends": 3,
    "surge_multiplier_default": 1.25,
    "minimum_payout_amount": 500
  }'
```

Success `200`: returns updated system config object.

### GET /admin/payouts

```bash
curl "$BASE_URL/admin/payouts" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns all payout requests and pagination `meta`.

### POST /admin/payouts/{id}/approve

```bash
curl -X POST "$BASE_URL/admin/payouts/pay_001/approve" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns payout request with `status: APPROVED`.

### POST /admin/payouts/{id}/reject

Important: rejection reason is a query parameter, not JSON body.

```bash
curl -X POST "$BASE_URL/admin/payouts/pay_001/reject?reason=bank%20details%20mismatch" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Success `200`: returns payout request with `status: REJECTED` and `rejection_reason`.

Common admin errors:

```json
{
  "success": false,
  "message": "insufficient permissions",
  "error_code": "FORBIDDEN"
}
```

```json
{
  "success": false,
  "message": "rider not found",
  "error_code": "RIDER_NOT_FOUND"
}
```

```json
{
  "success": false,
  "message": "order not found",
  "error_code": "ORDER_NOT_FOUND"
}
```

## Common protected-endpoint auth errors

Missing token:

```json
{
  "success": false,
  "message": "missing bearer token",
  "error_code": "UNAUTHORIZED"
}
```

Invalid token:

```json
{
  "success": false,
  "message": "invalid access token",
  "error_code": "INVALID_TOKEN"
}
```

Role denied:

```json
{
  "success": false,
  "message": "insufficient permissions",
  "error_code": "FORBIDDEN"
}
```

## Frontend implementation checklist

- Store `access_token` and `refresh_token` separately.
- Refresh on `401 UNAUTHORIZED` from protected endpoints, then retry once.
- Show field-level validation using the `errors` object directly.
- Treat `409` as business-state errors, not generic server errors.
- For order lifecycle buttons, always gate UI by the current `order.status`.
- For delivery completion, handle `PICKUP_OTP_REQUIRED` and `DELIVERY_OTP_REQUIRED` as modal flows.
- For lists, read `meta.page`, `meta.page_size`, `meta.total`, or `meta.count` when present.
- For admin payout rejection, send `reason` as query param.
- For `/riders/me/routes/{orderId}`, filter by `order_id` client-side until backend narrows that endpoint.
