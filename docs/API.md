# ABM.dev API Reference

External API documentation for ABM.dev platform customers.

## Base URL

```
https://api.abm.dev/v1
```

## Authentication

All authenticated endpoints require one of the following:

### JWT Bearer Token (User Authentication)
```
Authorization: Bearer <jwt_token>
```
JWT tokens are issued by Clerk and contain user identity and organization claims.

### API Key (Programmatic Access)
```
x-api-key: abmdev_<key>
```
API keys are scoped to an organization and can be created via the API Keys endpoints.

---

## Enrichment API

Core product endpoints for entity enrichment.

### POST /v1/enrichments

Enrich a single entity or multiple entities in bulk.

**Rate Limit:** 20 requests/minute

**Single Entity Request:**
```json
{
  "entity_type": "person",
  "entity_data": {
    "email": "john@example.com",
    "first_name": "John",
    "last_name": "Doe"
  }
}
```

**Bulk Request (multiple entities):**
```json
{
  "bulk": true,
  "entities": [
    {
      "entity_type": "person",
      "entity_data": { "email": "john@example.com" }
    },
    {
      "entity_type": "company",
      "entity_data": { "domain": "acme.com" }
    }
  ]
}
```

**Response:**
```json
{
  "job_id": "job_abc123",
  "status": "processing",
  "entities_count": 1
}
```

---

### GET /v1/enrichment/jobs

List enrichment jobs for your organization.

**Query Parameters:**
- `status` - Filter by status (pending, processing, completed, failed)
- `limit` - Number of results (default: 20, max: 100)
- `offset` - Pagination offset

**Response:**
```json
{
  "jobs": [
    {
      "id": "job_abc123",
      "status": "completed",
      "entities_count": 10,
      "enriched_count": 8,
      "created_at": "2024-01-15T10:30:00Z",
      "completed_at": "2024-01-15T10:32:15Z"
    }
  ],
  "total": 25,
  "limit": 20,
  "offset": 0
}
```

---

### POST /v1/enrichment/jobs

Create a new enrichment job.

**Request:**
```json
{
  "name": "Q1 Lead Enrichment",
  "configuration_id": "config_xyz789",
  "entities": [
    { "entity_type": "person", "entity_data": {...} }
  ]
}
```

---

### GET /v1/enrichment/jobs/{jobId}

Get details of a specific enrichment job.

**Response:**
```json
{
  "id": "job_abc123",
  "name": "Q1 Lead Enrichment",
  "status": "processing",
  "progress": 45,
  "entities_count": 100,
  "enriched_count": 45,
  "failed_count": 2,
  "created_at": "2024-01-15T10:30:00Z"
}
```

---

### DELETE /v1/enrichment/jobs/{jobId}

Cancel a pending or processing job.

---

### GET /v1/enrichment/jobs/{jobId}/stream

Server-Sent Events (SSE) stream for real-time job progress.

**Response (SSE):**
```
event: progress
data: {"job_id":"job_abc123","progress":45,"status":"processing"}

event: complete
data: {"job_id":"job_abc123","progress":100,"status":"completed"}
```

---

### POST /v1/enrichment/preflight

Pre-flight analysis to estimate enrichment results before running.

**Request:**
```json
{
  "entity_type": "person",
  "entity_data": {
    "email": "john@example.com"
  }
}
```

**Response:**
```json
{
  "available_sources": ["linkedin", "hunter", "clearbit"],
  "estimated_fields": 15,
  "confidence": "high"
}
```

---

## Enrichment Configuration

Manage enrichment configurations and field mappings.

### GET /v1/enrichment/configurations

List all enrichment configurations.

### POST /v1/enrichment/configurations

Create a new enrichment configuration.

**Request:**
```json
{
  "name": "Standard Person Enrichment",
  "entity_type": "person",
  "sources": ["linkedin", "hunter"],
  "field_mappings": [...],
  "settings": {
    "auto_sync_to_crm": true
  }
}
```

### GET /v1/enrichment/configurations/{configId}

Get a specific configuration.

### PUT /v1/enrichment/configurations/{configId}

Update a configuration.

### DELETE /v1/enrichment/configurations/{configId}

Delete a configuration.

---

### GET /v1/enrichment/field-mappings

List field mappings for your organization.

### POST /v1/enrichment/field-mappings

Create a new field mapping.

### GET /v1/enrichment/field-mappings/{mappingId}

Get a specific field mapping.

### PUT /v1/enrichment/field-mappings/{mappingId}

Update a field mapping.

### DELETE /v1/enrichment/field-mappings/{mappingId}

Delete a field mapping.

---

## CRM API

Generic, platform-agnostic CRM integration.

### CRM Configuration

#### GET /v1/crm/config/platforms

List supported CRM platforms.

**Response:**
```json
{
  "platforms": [
    {
      "id": "hubspot",
      "name": "HubSpot",
      "connected": true,
      "status": "active"
    },
    {
      "id": "salesforce",
      "name": "Salesforce",
      "connected": false,
      "status": "not_connected"
    }
  ]
}
```

---

#### GET /v1/crm/config/platforms/{platform}/health

Check CRM connection health.

**Response:**
```json
{
  "platform": "hubspot",
  "status": "healthy",
  "last_sync": "2024-01-15T10:30:00Z",
  "rate_limit_remaining": 450
}
```

---

#### GET /v1/crm/config/platforms/{platform}/fields

Get available fields from the CRM.

**Response:**
```json
{
  "platform": "hubspot",
  "object_type": "contact",
  "fields": [
    {
      "name": "email",
      "label": "Email",
      "type": "string",
      "required": true
    },
    {
      "name": "firstname",
      "label": "First Name",
      "type": "string",
      "required": false
    }
  ]
}
```

---

#### GET /v1/crm/config/platforms/{platform}/mappings

Get field mappings for a specific CRM platform.

---

#### GET /v1/crm/config/translate/to-platform

Translate canonical field names to CRM-specific names.

**Query Parameters:**
- `platform` - Target CRM platform (e.g., "hubspot")
- `field` - Canonical field name to translate

---

#### GET /v1/crm/config/translate/to-canonical

Translate CRM-specific field names to canonical names.

**Query Parameters:**
- `platform` - Source CRM platform (e.g., "hubspot")
- `field` - CRM field name to translate

---

### CRM Integrations

Manage CRM integration connections (e.g., HubSpot Private App tokens).

#### POST /v1/crm/config/integrations/test

Test a CRM API key before saving.

**Rate Limit:** 5 requests/minute (strict limit to prevent enumeration)

**Request:**
```json
{
  "integrationType": "hubspot",
  "apiKey": "pat-na1-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

**Response (Success):**
```json
{
  "data": {
    "connected": true,
    "integration_type": "hubspot",
    "portal_id": "12345678",
    "test_status": "success",
    "error_message": null,
    "rate_limit": {
      "remaining": 95,
      "limit": 100
    }
  },
  "success": true
}
```

**Response (Failure):**
```json
{
  "data": {
    "connected": false,
    "integration_type": "hubspot",
    "portal_id": null,
    "test_status": "failed",
    "error_message": "Invalid API key or insufficient permissions"
  },
  "success": true
}
```

---

#### GET /v1/crm/config/integrations

List all integrations for your organization.

**Query Parameters:**
- `activeOnly` - Only return active integrations (default: true)

**Response:**
```json
{
  "data": {
    "integrations": [
      {
        "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
        "integration_type": "hubspot",
        "display_name": "My HubSpot Account",
        "portal_id": "12345678",
        "is_active": true,
        "test_status": "success",
        "last_tested_at": "2024-01-15T12:00:00Z",
        "created_at": "2024-01-15T12:00:00Z"
      }
    ],
    "total_count": 1
  },
  "success": true
}
```

---

#### POST /v1/crm/config/integrations

Create a new CRM integration. Requires Admin role.

**Request:**
```json
{
  "integrationType": "hubspot",
  "displayName": "My HubSpot Account",
  "apiKey": "pat-na1-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "portalId": "12345678",
  "isActive": true
}
```

**Response (201 Created):**
```json
{
  "data": {
    "id": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
    "integration_type": "hubspot",
    "display_name": "My HubSpot Account",
    "portal_id": "12345678",
    "is_active": true,
    "test_status": "success",
    "created_at": "2024-01-15T12:00:00Z"
  },
  "success": true
}
```

---

#### GET /v1/crm/config/integrations/{integrationId}

Get a specific integration by ID.

---

#### DELETE /v1/crm/config/integrations/{integrationId}

Delete an integration. Requires Admin role.

**Response:** 204 No Content

---

### CRM Contacts

#### POST /v1/crm/contacts

Create a contact in the connected CRM.

**Request:**
```json
{
  "platform": "hubspot",
  "properties": {
    "email": "john@example.com",
    "firstname": "John",
    "lastname": "Doe"
  }
}
```

---

#### POST /v1/crm/contacts/search

Search contacts in the CRM.

**Request:**
```json
{
  "platform": "hubspot",
  "filters": [
    { "property": "email", "operator": "contains", "value": "@example.com" }
  ],
  "limit": 50
}
```

---

#### GET /v1/crm/contacts/{contactId}

Get a contact by ID.

#### PATCH /v1/crm/contacts/{contactId}

Update a contact.

#### DELETE /v1/crm/contacts/{contactId}

Delete a contact.

---

### CRM Companies

#### POST /v1/crm/companies

Create a company in the connected CRM.

**Request:**
```json
{
  "platform": "hubspot",
  "properties": {
    "name": "Acme Corp",
    "domain": "acme.com",
    "industry": "Technology"
  }
}
```

---

#### POST /v1/crm/companies/search

Search companies in the CRM.

**Request:**
```json
{
  "platform": "hubspot",
  "filters": [
    { "property": "domain", "operator": "equals", "value": "acme.com" }
  ],
  "limit": 50
}
```

---

#### GET /v1/crm/companies/{companyId}

Get a company by ID.

#### PATCH /v1/crm/companies/{companyId}

Update a company.

#### DELETE /v1/crm/companies/{companyId}

Delete a company.

---

## Organizations

Manage organization settings and usage.

### GET /v1/organizations/current

Get the current organization.

**Response:**
```json
{
  "id": "org_abc123",
  "name": "Acme Corp",
  "slug": "acme-corp",
  "tier": "pro",
  "status": "active",
  "limits": {
    "max_api_keys": 10,
    "max_workspaces": 5,
    "max_members": 25,
    "rate_limit_per_minute": 100
  }
}
```

---

### GET /v1/organizations/current/usage

Get usage statistics for the current billing period.

**Response:**
```json
{
  "period": {
    "start": "2024-01-01T00:00:00Z",
    "end": "2024-01-31T23:59:59Z"
  },
  "enrichments": {
    "used": 1500,
    "limit": 5000,
    "remaining": 3500
  },
  "api_calls": {
    "used": 12500,
    "limit": 100000,
    "remaining": 87500
  }
}
```

---

## API Keys

Manage programmatic API access.

### GET /v1/api-keys

List API keys for your organization.

**Response:**
```json
{
  "api_keys": [
    {
      "id": "key_abc123",
      "name": "Production Key",
      "prefix": "abmdev_prod_",
      "environment": "production",
      "scopes": ["enrichment:read", "enrichment:write"],
      "created_at": "2024-01-10T08:00:00Z",
      "last_used_at": "2024-01-15T14:30:00Z"
    }
  ]
}
```

---

### POST /v1/api-keys

Create a new API key.

**Request:**
```json
{
  "name": "CI/CD Pipeline Key",
  "environment": "production",
  "scopes": ["enrichment:read", "enrichment:write"],
  "allowed_ips": ["192.168.1.0/24"],
  "expires_at": "2024-12-31T23:59:59Z"
}
```

**Response:**
```json
{
  "id": "key_xyz789",
  "name": "CI/CD Pipeline Key",
  "key": "abmdev_prod_abc123xyz...",
  "created_at": "2024-01-15T10:00:00Z"
}
```

> **Important:** The full API key is only shown once upon creation. Store it securely.

---

### DELETE /v1/api-keys/{keyId}

Revoke an API key.

---

## Status & Health

### GET /v1/status

Get API status and service health.

**Response:**
```json
{
  "status": "operational",
  "version": "1.0.0",
  "services": {
    "api": "healthy",
    "database": "healthy",
    "redis": "healthy"
  }
}
```

---

### GET /health

Health check endpoint (no authentication required).

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

## Error Handling

All errors return a consistent JSON format:

```json
{
  "error": "Unauthorized",
  "message": "Invalid or expired API key",
  "correlationId": "req_abc123xyz",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request - Invalid input |
| 401 | Unauthorized - Missing or invalid authentication |
| 403 | Forbidden - Insufficient permissions |
| 404 | Not Found |
| 429 | Too Many Requests - Rate limit exceeded |
| 500 | Internal Server Error |

---

## Rate Limiting

Rate limits are applied per organization:

| Endpoint Category | Limit |
|-------------------|-------|
| Enrichment endpoints | 20 requests/minute |
| All other endpoints | 100 requests/minute |
| Global fallback | 1000 requests/minute |

Rate limit headers are included in all responses:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1705316400
```
