#!/usr/bin/env bash
# Read-only Chrome/TLS/network diagnostics for an AtlasOS Ubuntu Live session.
# No certificates are installed, no network settings are changed, and no TLS
# verification is disabled. Output deliberately omits SSIDs, proxy values,
# DNS addresses, browser profiles, URL paths, and response bodies.
set +e
export LC_ALL=C

echo '=== AtlasOS Chrome network diagnostics ==='
echo 'BEGIN'

section() { printf '\n--- %s ---\n' "$1"; }

section '1. OS, clock, and Live-session context'
. /etc/os-release 2>/dev/null
printf 'OS=%s %s\n' "${ID:-unknown}" "${VERSION_ID:-unknown}"
printf 'KERNEL=%s\n' "$(uname -sr)"
printf 'CURRENT_UTC=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo unavailable)"
printf 'EPOCH_SECONDS=%s\n' "$(date -u '+%s' 2>/dev/null || echo unavailable)"
if command -v timedatectl >/dev/null 2>&1; then
    for property in Timezone NTPSynchronized NTP TimeUSec; do
        value=$(timedatectl show --property="$property" --value 2>/dev/null)
        [ -n "$value" ] && printf 'TIME_%s=%s\n' "$property" "$value"
    done
else
    echo 'TIMEDATECTL=unavailable'
fi
for unit in systemd-timesyncd chrony chronyd; do
    if command -v systemctl >/dev/null 2>&1; then
        state=$(systemctl is-active "$unit" 2>/dev/null)
        [ -n "$state" ] && printf 'TIME_SERVICE_%s=%s\n' "$unit" "$state"
    fi
done
if grep -Eq '(^|[[:space:]])boot=casper|(^|[[:space:]])live-media=' /proc/cmdline 2>/dev/null; then
    echo 'BOOT_MODE=live_media_detected'
else
    echo 'BOOT_MODE=live_media_not_detected'
fi

section '2. CA package and system trust bundle'
if command -v dpkg-query >/dev/null 2>&1; then
    ca_version=$(dpkg-query -W -f='${Version}' ca-certificates 2>/dev/null)
    printf 'CA_CERTIFICATES_PACKAGE=%s\n' "${ca_version:-not_installed}"
else
    echo 'DPKG_QUERY=unavailable'
fi
bundle=/etc/ssl/certs/ca-certificates.crt
if [ -r "$bundle" ]; then
    printf 'SYSTEM_CA_BUNDLE=present bytes=%s modified=%s\n' \
        "$(stat -c '%s' "$bundle" 2>/dev/null || echo unknown)" \
        "$(stat -c '%y' "$bundle" 2>/dev/null | cut -c1-19 || echo unknown)"
else
    echo 'SYSTEM_CA_BUNDLE=missing_or_unreadable'
fi
if command -v update-ca-certificates >/dev/null 2>&1; then
    echo 'UPDATE_CA_CERTIFICATES_TOOL=present'
else
    echo 'UPDATE_CA_CERTIFICATES_TOOL=missing'
fi

section '3. Chrome executable, policy, and proxy configuration'
chrome_bin=''
for candidate in google-chrome google-chrome-stable chromium chromium-browser; do
    resolved=$(command -v "$candidate" 2>/dev/null)
    if [ -n "$resolved" ]; then
        chrome_bin=$resolved
        printf 'BROWSER_EXECUTABLE=%s\n' "$candidate"
        "$resolved" --version 2>/dev/null | head -n 1 | sed 's/^[[:space:]]*//'
        break
    fi
done
[ -n "$chrome_bin" ] || echo 'BROWSER_EXECUTABLE=not_found'

python3 - <<'PY'
import json
from pathlib import Path

roots = [
    Path('/etc/opt/chrome/policies/managed'),
    Path('/etc/opt/chrome/policies/recommended'),
    Path('/etc/chromium/policies/managed'),
    Path('/etc/chromium/policies/recommended'),
]
proxy_keys = {'ProxyMode', 'ProxyServer', 'ProxyPacUrl', 'ProxyBypassList'}
found = []
proxy_found = []
bad_json = 0
for root in roots:
    if not root.is_dir():
        continue
    for path in root.rglob('*.json'):
        try:
            data = json.loads(path.read_text(encoding='utf-8'))
        except Exception:
            bad_json += 1
            continue
        if isinstance(data, dict):
            keys = set(data)
            found.extend(sorted(keys))
            proxy_found.extend(sorted(keys & proxy_keys))
print('BROWSER_POLICY_FILES_WITH_PROXY_VALUES=' + str(len(proxy_found) > 0).lower())
print('BROWSER_POLICY_KEYS=' + (','.join(sorted(set(found))) if found else 'none_detected'))
print('BROWSER_PROXY_POLICY_KEYS=' + (','.join(sorted(set(proxy_found))) if proxy_found else 'none_detected'))
print('BROWSER_POLICY_JSON_PARSE_FAILURES=' + str(bad_json))

# Report only the presence of proxy-related environment variables, never values.
env_names = ('http_proxy', 'https_proxy', 'all_proxy', 'no_proxy')
present = [name for name in env_names if __import__('os').environ.get(name) or __import__('os').environ.get(name.upper())]
print('PROXY_ENVIRONMENT_VARIABLES=' + (','.join(present) if present else 'none'))
PY

if command -v gsettings >/dev/null 2>&1; then
    proxy_mode=$(gsettings get org.gnome.system.proxy mode 2>/dev/null | tr -d "'\"" | tr -cd '[:alnum:]_-')
    printf 'DESKTOP_PROXY_MODE=%s\n' "${proxy_mode:-unavailable}"
else
    echo 'DESKTOP_PROXY_MODE=unavailable'
fi

if command -v pgrep >/dev/null 2>&1; then
    found_proxy_flags=false
    for pid in $(pgrep -f 'chrome|chromium' 2>/dev/null); do
        [ -r "/proc/$pid/cmdline" ] || continue
        if tr '\0' '\n' <"/proc/$pid/cmdline" | grep -Eq '^--proxy-(server|pac-url|bypass-list)(=|$)'; then
            found_proxy_flags=true
            break
        fi
    done
    printf 'RUNNING_BROWSER_PROXY_FLAGS=%s\n' "$found_proxy_flags"
else
    echo 'RUNNING_BROWSER_PROXY_FLAGS=process_inspection_unavailable'
fi

section '4. NetworkManager, resolver, and competing network configuration'
if command -v nmcli >/dev/null 2>&1; then
    nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | while IFS=: read -r dev type state; do
        [ -n "$dev" ] && printf 'NM_DEVICE type=%s state=%s\n' "$type" "$state"
    done
    nm_state=$(systemctl is-active NetworkManager 2>/dev/null)
    printf 'NETWORKMANAGER_SERVICE=%s\n' "${nm_state:-unknown}"
else
    echo 'NMCLI=unavailable'
fi

if command -v resolvectl >/dev/null 2>&1; then
    resolvectl_status=$(resolvectl status 2>/dev/null)
    if [ -n "$resolvectl_status" ]; then
        printf '%s\n' "$resolvectl_status" | awk '
            /^[[:space:]]*Link [0-9]+ \(/ { link=$0; sub(/^[[:space:]]*/, "", link); next }
            /^[[:space:]]*Current Scopes:/ { scopes=$0; sub(/^[[:space:]]*/, "", scopes); next }
            /^[[:space:]]*Protocols:/ { protocols=$0; sub(/^[[:space:]]*/, "", protocols); next }
            /^[[:space:]]*DNS Servers:/ { value=$0; sub(/^[^:]*:[[:space:]]*/, "", value); n=split(value, a, /[[:space:]]+/); printf "RESOLVER_DNS_SERVER_COUNT link=%s count=%d\n", link, n; next }
            END { if (NR==0) print "RESOLVER_STATUS=unavailable" }
        '
    else
        echo 'RESOLVER_STATUS=unavailable'
    fi
else
    echo 'RESOLVER_STATUS=unavailable'
fi

if [ -L /etc/resolv.conf ]; then
    printf 'RESOLV_CONF=symlink target=%s\n' "$(readlink /etc/resolv.conf | sed 's#^.*/##')"
elif [ -r /etc/resolv.conf ]; then
    echo 'RESOLV_CONF=regular_file'
else
    echo 'RESOLV_CONF=missing_or_unreadable'
fi

python3 - <<'PY'
from pathlib import Path

root = Path('/etc/NetworkManager')
files = sorted(root.glob('NetworkManager.conf')) + sorted((root / 'conf.d').glob('*.conf'))
managed_false = 0
unmanaged_rules = 0
dns_settings = 0
for path in files:
    try:
        text = path.read_text(encoding='utf-8', errors='replace')
    except OSError:
        continue
    for line in text.splitlines():
        clean = line.split('#', 1)[0].strip().lower()
        if clean.startswith('managed=') and clean.split('=', 1)[1].strip() in {'false', 'no', '0'}:
            managed_false += 1
        if clean.startswith('unmanaged-devices=') and clean.split('=', 1)[1].strip():
            unmanaged_rules += 1
        if clean.startswith('dns=') or clean.startswith('rc-manager='):
            dns_settings += 1
print('NM_CONFIG_FILES=' + str(len(files)))
print('NM_CONFIG_MANAGED_FALSE_RULES=' + str(managed_false))
print('NM_CONFIG_UNMANAGED_DEVICE_RULES=' + str(unmanaged_rules))
print('NM_CONFIG_DNS_OR_RC_MANAGER_OVERRIDES=' + str(dns_settings))

interfaces = Path('/etc/network/interfaces')
if interfaces.is_file():
    lines = [line.strip() for line in interfaces.read_text(errors='replace').splitlines()
             if line.strip() and not line.lstrip().startswith('#')]
    print('ETC_NETWORK_INTERFACES_ACTIVE_LINES=' + str(len(lines)))
else:
    print('ETC_NETWORK_INTERFACES=absent')

netplan = Path('/etc/netplan')
files = sorted(netplan.glob('*.yaml')) + sorted(netplan.glob('*.yml')) if netplan.is_dir() else []
renderers = set()
for path in files:
    try:
        for line in path.read_text(errors='replace').splitlines():
            stripped = line.strip()
            if stripped.startswith('renderer:'):
                renderers.add(stripped.split(':', 1)[1].strip().lower())
    except OSError:
        pass
print('NETPLAN_FILES=' + str(len(files)))
print('NETPLAN_RENDERERS=' + (','.join(sorted(renderers)) if renderers else 'none_detected'))
PY

section '5. Fixed HTTPS and captive-portal probes (TLS verification remains enabled)'
if ! command -v curl >/dev/null 2>&1; then
    echo 'CURL=unavailable'
else
    for host in www.google.com www.eba.gov.tr ogmmateryal.eba.gov.tr mebi.eba.gov.tr; do
        result=$(curl --silent --show-error --connect-timeout 5 --max-time 12 \
            --output /dev/null \
            --write-out '%{http_code} %{ssl_verify_result} %{num_redirects}' \
            "https://${host}/" 2>/dev/null)
        rc=$?
        if [ -z "$result" ]; then result='000 0 0'; fi
        read -r http_code verify redirects <<<"$result"
        case "$rc" in
            0) category='https_ok' ;;
            5|6) category='proxy_or_dns_resolution' ;;
            7) category='tcp_connect_failed' ;;
            28) category='timeout' ;;
            35) category='tls_handshake_failed' ;;
            51|60|77) category='certificate_validation_failed' ;;
            56) category='connection_reset_or_receive_failure' ;;
            *) category='other_curl_error' ;;
        esac
        printf 'HTTPS_PROBE host=%s curl_exit=%s http=%s tls_verify=%s redirects=%s category=%s\n' \
            "$host" "$rc" "${http_code:-000}" "${verify:-unknown}" "${redirects:-0}" "$category"
    done
    portal=$(curl --silent --show-error --location --max-redirs 3 --connect-timeout 5 --max-time 12 \
        --output /dev/null --write-out '%{http_code} %{num_redirects}' \
        'http://connectivity-check.ubuntu.com/' 2>/dev/null)
    portal_rc=$?
    [ -n "$portal" ] || portal='000 0'
    read -r portal_http portal_redirects <<<"$portal"
    printf 'CAPTIVE_PORTAL_HTTP_CHECK curl_exit=%s http=%s redirects=%s (redirect destination intentionally omitted)\n' \
        "$portal_rc" "${portal_http:-000}" "${portal_redirects:-0}"
fi

section '6. Result interpretation hints'
echo 'CLOCK: wrong date or NTPSynchronized=no can break otherwise valid TLS.'
echo 'CA: missing CA package/bundle or curl certificate-validation failure supports a system trust problem.'
echo 'INTERCEPTION: public HTTPS certificate failure on this network, especially with a custom issuer in Chrome, supports filtering/proxy interception; this script does not expose issuer names.'
echo 'CHROME_POLICY: proxy policy keys, browser proxy flags, or manual/auto desktop proxy mode indicate configured proxy behavior.'
echo 'LIVE_NETWORK: disconnected devices, no resolver, failed DNS probes, or a detected competing renderer support a Live network configuration difference.'
echo 'A successful curl probe does not prove Chrome works; a failing probe does not alone identify the school network root cause.'
echo 'CHROME_UI_CHECK: before rerunning, open chrome://policy and chrome://settings/system; report whether a policy is present and whether Chrome says system proxy is used. Do not copy profile paths or proxy URLs.'
echo 'LIVE_VS_INSTALLED: this script snapshots only the running Live OS; compare these same fields after booting the installed OS to check for configuration differences.'
echo 'END'
echo '=== End diagnostics ==='
