# Website Logo & URL Auto-Capture Feature

## Overview

When creating a password entry for a website, CredLock now automatically:
- Fetches the website's favicon/logo
- Resolves the canonical URL
- Auto-fills the URL field

## How It Works

### User Flow
1. User selects "Website" category
2. User types a website name (e.g., "google", "github.com", "twitter")
3. After 700ms debounce, CredLock:
   - Parses the domain from the input
   - Fetches the favicon from multiple sources
   - Auto-fills the URL field with `https://domain.com`
   - Displays the favicon next to the name field

### Technical Implementation

**Service**: `lib/core/services/website_lookup_service.dart`

**Features**:
- Smart domain parsing (handles "google", "github.com", "https://twitter.com")
- Auto-adds `.com` if no TLD provided
- Strips protocol, www, paths, and query params
- Fetches favicon from 3 sources in order:
  1. Google's favicon service (most reliable, 64px)
  2. DuckDuckGo's favicon service (fallback)
  3. Direct `favicon.ico` from domain
- Validates image bytes (PNG, JPEG, GIF, ICO, WebP)
- Caches results per domain
- 5-second timeout per request

**UI Integration**:
- 700ms debounce to avoid excessive requests while typing
- Loading indicator while fetching
- Favicon preview with ✕ badge to clear
- Auto-fills URL only if user hasn't typed one yet
- Stores favicon as base64 in database (same as mobile apps)

## Database Schema

No changes needed — reuses existing `app_icon_base64` column:
- Mobile entries: stores app icon
- Website entries: stores favicon

## Network Requirements

- Added `http: ^1.2.2` package
- Added `INTERNET` permission to AndroidManifest.xml
- All requests use HTTPS
- Graceful fallback if network unavailable

## Security Considerations

- Only fetches from trusted sources (Google, DuckDuckGo, direct domain)
- Validates image format before storing
- No user data sent to external services
- Favicon stored encrypted in database (via existing encryption)

## User Experience

**Before**:
- User manually types website name and URL
- No visual indicator of which website

**After**:
- User types "github" → sees GitHub logo, URL auto-filled to `https://github.com`
- User types "google.com" → sees Google logo, URL auto-filled
- User types "https://twitter.com/home" → sees Twitter logo, URL cleaned to `https://twitter.com`
- Vault list shows website logos for easy identification

## Limitations

- Requires internet connection
- Some websites may not have favicons
- Favicon quality depends on source availability
- 5-second timeout per source (max 15s total)

## Future Enhancements

- [ ] Offline mode with cached favicons
- [ ] Higher resolution favicon support
- [ ] Custom favicon upload option
- [ ] Favicon refresh/update mechanism
- [ ] Support for SVG favicons
