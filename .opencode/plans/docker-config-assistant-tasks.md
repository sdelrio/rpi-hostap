# Docker Config Assistant - Task Breakdown

## Overview
Create an interactive configuration assistant page in the existing Astro docs-site that generates Docker env files and `docker run` commands for rpi-hostap.

---

## Task 1: Create New Page & Layout
**Labels**: `enhancement`, `ready`

Create a new Astro page at `docs-site/src/content/docs/configuration-assistant.md` (or `.mdx`) with the necessary layout and routing.

**Acceptance Criteria**:
- New page accessible at `/configuration-assistant/`
- Added to sidebar navigation in `astro.config.mjs`
- Page includes a descriptive header explaining the tool
- Layout matches existing docs-site styling

---

## Task 2: Build Form Component - Band & Country Selection
**Labels**: `enhancement`, `ready`

Create the first section of the configuration form with band and country code selection.

**Acceptance Criteria**:
- Radio buttons or dropdown for band selection:
  - 802.11b (HW_MODE=b)
  - 802.11g/n (HW_MODE=g) - 2.4GHz
  - 802.11a/n/ac/ax (HW_MODE=a) - 5GHz
- Dropdown for country code (US, CA, MX, EU/ETSI, JP, etc.)
- Country code affects available channel options
- Form state management (vanilla JS or lightweight library)

---

## Task 3: Build Form Component - Channel Selection
**Labels**: `enhancement`, `ready`

Dynamic channel selector that updates based on band and country selection.

**Acceptance Criteria**:
- 2.4GHz channels: 1-14 (varies by country)
- 5GHz channels: 36, 40, 44, 48, 52, 56, 60, 64, 100-144, 149, 153, 157, 161, 165
- "Auto" option for ACS (CHANNEL=acs)
- Visual indication of DFS channels (52-144)
- Channel list updates dynamically when band or country changes

---

## Task 4: Build Form Component - Security Settings
**Labels**: `enhancement`, `ready`

WPA/PMF configuration section.

**Acceptance Criteria**:
- WPA Version selector: WPA2-PSK, WPA3-SAE, WPA2/WPA3 Mixed
- Passphrase input with validation (8-63 chars)
- PMF selector: Disabled (0), Optional (1), Required (2)
- Auto-set PMF based on WPA version (WPA3=2, Mixed=1, WPA2=0)

---

## Task 5: Build Form Component - Radio Capabilities
**Labels**: `enhancement`, `ready`

HT/VHT/HE (802.11n/ac/ax) capability configuration.

**Acceptance Criteria**:
- HT (802.11n) checkbox to enable
- HT Capabilities input (e.g., `[HT40+][SHORT-GI-20]`)
- VHT (802.11ac) checkbox (only enabled when HW_MODE=a)
- VHT Capabilities input
- HE (802.11ax/Wi-Fi 6) checkbox (only enabled when HW_MODE=a)
- HE Capabilities input
- Visual validation that VHT/HE require 5GHz band

---

## Task 6: Build Form Component - Network Settings
**Labels**: `enhancement`, `ready`

DHCP and networking configuration section.

**Acceptance Criteria**:
- Subnet input (default: 192.168.254.0)
- AP Address input (default: 192.168.254.1)
- DHCP Range inputs (start, end, or auto-compute from subnet)
- DHCP Lease time input (default: 12h)
- Primary DNS input (default: 8.8.8.8)
- Secondary DNS input (default: 8.8.4.4)
- IPv6 toggle (default: off)

---

## Task 7: Build Form Component - Advanced Options
**Labels**: `enhancement`, `ready`

Additional configuration options.

**Acceptance Criteria**:
- SSID input (default: raspberry)
- Hide SSID toggle
- Max Stations input (0 = unlimited)
- AP Isolation toggle
- MAC Filter selector (Off, Allowlist, Denylist)
- TX Power input (dBm or auto)
- Interface name input (default: wlan0)
- Driver input (only if non-default needed)

---

## Task 8: Build Output Generator - Env File
**Labels**: `enhancement`, `ready`

Generate Docker env file output from form state.

**Acceptance Criteria**:
- Read-only textarea showing generated env file
- Format: `KEY=VALUE` per line
- Only include non-default values (or option to include all)
- Copy-to-clipboard button
- Updates live as form changes
- Include comments explaining each variable

---

## Task 9: Build Output Generator - Docker Run Command
**Labels**: `enhancement`, `ready`

Generate docker run command from form state.

**Acceptance Criteria**:
- Read-only textarea showing complete `docker run` command
- Uses `-e KEY=VALUE` flags for each variable
- Includes required flags: `--privileged`, `--net host`
- Includes image name placeholder (configurable)
- Copy-to-clipboard button
- Updates live as form changes

---

## Task 10: Add Form Validation & Defaults
**Labels**: `enhancement`, `ready`

Implement form validation and sensible defaults.

**Acceptance Criteria**:
- Validate SSID (1-32 chars, no special chars)
- Validate passphrase (8-63 chars)
- Validate subnet format
- Validate channel is in allowed list for selected band/country
- Highlight invalid fields with error messages
- "Reset to Defaults" button
- Load defaults matching the current README defaults

---

## Task 11: Style & Polish
**Labels**: `enhancement`, `ready`

Style the form to match docs-site theme and improve UX.

**Acceptance Criteria**:
- Form uses existing docs-site CSS variables and theme
- Responsive layout (works on mobile)
- Sections with clear headings and descriptions
- Tooltips or help text for complex options
- Visual feedback when copying to clipboard
- Dark mode support (inherits from ThemeProvider)

---

## Task 12: Add Documentation
**Labels**: `docs`, `ready`

Add usage documentation for the configuration assistant.

**Acceptance Criteria**:
- Brief intro on the page explaining what the tool does
- Instructions for using the generated env file or docker run command
- Notes about required flags (--privileged, --net host)
- Link to full configuration documentation

---

## Suggested Implementation Order

1. **Task 1** - Page setup (foundation)
2. **Task 2** - Band & Country (core selection)
3. **Task 3** - Channel (depends on Task 2)
4. **Task 4** - Security settings
5. **Task 5** - Radio capabilities
6. **Task 6** - Network settings
7. **Task 7** - Advanced options
8. **Task 10** - Validation (can be done alongside form components)
9. **Task 8** - Env file output (depends on form components)
10. **Task 9** - Docker run output (depends on form components)
11. **Task 11** - Styling (after functionality works)
12. **Task 12** - Documentation (final)

---

## Technical Notes

### Existing Components to Reuse
- `Card.astro` and `CardGrid.astro` for layout sections
- `ThemeProvider.astro` already handles dark mode
- CSS variables in `custom.css` for consistent theming

### Form Implementation Options
- **Vanilla JS**: Lightweight, no dependencies, easy to maintain
- **Astro Islands**: Interactive components with client-side JS
- Consider using `<script>` tags in Astro components for interactivity

### Channel Data Source
- Can reference `lib/core/channel.sh` for validation logic
- Or hardcode channel lists based on IEEE 802.11 standards

### Output Format Reference
- Env file: See README.md "Configuration" section
- Docker run: See README.md "Quick Start" section
