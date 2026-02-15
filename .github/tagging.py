#!/usr/bin/env python3
"""
Proxy Configuration Processor

This script processes proxy configurations by:
1. Tagging proxies with country emojis and CDN detection
2. Removing duplicates
3. Sorting proxies alphabetically
4. Organizing them into a selector outbound
"""

import json
import socket
import os
import subprocess
from typing import Optional, Dict, Set, Tuple, Any, List

# Configuration
CONFIG_PATH = ".github/final.json"
GEOIP_DB_PATH = ".github/geoip.db"
SING_BOX_PATH = "sing-box"  # or full path if not in PATH
TIMEOUT = 10

PROXY_TYPES = (
    "vmess", "trojan", "shadowsocks", "vless",
    "hysteria", "hysteria2", "tuic", "wireguard",
    "anytls", "shadowtls", "socks", "http"
)

# CDN categories
CDN_CATEGORIES = {
    "cloudflare", "google", "amazon", "microsoft",
    "oracle", "digitalocean", "linode", "gcore"
}

# Country Emoji Mapping
COUNTRY_EMOJIS = {
    "ad": "🇦🇩", "ae": "🇦🇪", "af": "🇦🇫", "ag": "🇦🇬", "ai": "🇦🇮",
    "al": "🇦🇱", "am": "🇦🇲", "ao": "🇦🇴", "aq": "🇦🇶", "ar": "🇦🇷",
    "as": "🇦🇸", "at": "🇦🇹", "au": "🇦🇺", "aw": "🇦🇼", "ax": "🇦🇽",
    "az": "🇦🇿", "ba": "🇧🇦", "bb": "🇧🇧", "bd": "🇧🇩", "be": "🇧🇪",
    "bf": "🇧🇫", "bg": "🇧🇬", "bh": "🇧🇭", "bi": "🇧🇮", "bj": "🇧🇯",
    "bl": "🇧🇱", "bm": "🇧🇲", "bn": "🇧🇳", "bo": "🇧🇴", "bq": "🇧🇶",
    "br": "🇧🇷", "bs": "🇧🇸", "bt": "🇧🇹", "bv": "🇧🇻", "bw": "🇧🇼",
    "by": "🇧🇾", "bz": "🇧🇿", "ca": "🇨🇦", "cc": "🇨🇨", "cd": "🇨🇩",
    "cf": "🇨🇫", "cg": "🇨🇬", "ch": "🇨🇭", "ci": "🇨🇮", "ck": "🇨🇰",
    "cl": "🇨🇱", "cm": "🇨🇲", "cn": "🇨🇳", "co": "🇨🇴", "cr": "🇨🇷",
    "cu": "🇨🇺", "cv": "🇨🇻", "cw": "🇨🇼", "cx": "🇨🇽", "cy": "🇨🇾",
    "cz": "🇨🇿", "de": "🇩🇪", "dj": "🇩🇯", "dk": "🇩🇰", "dm": "🇩🇲",
    "do": "🇩🇴", "dz": "🇩🇿", "ec": "🇪🇨", "ee": "🇪🇪", "eg": "🇪🇬",
    "eh": "🇪🇭", "er": "🇪🇷", "es": "🇪🇸", "et": "🇪🇹", "fi": "🇫🇮",
    "fj": "🇫🇯", "fk": "🇫🇰", "fm": "🇫🇲", "fo": "🇫🇴", "fr": "🇫🇷",
    "ga": "🇬🇦", "gb": "🇬🇧", "gd": "🇬🇩", "ge": "🇬🇪", "gf": "🇬🇫",
    "gg": "🇬🇬", "gh": "🇬🇭", "gi": "🇬🇮", "gl": "🇬🇱", "gm": "🇬🇲",
    "gn": "🇬🇳", "gp": "🇬🇵", "gq": "🇬🇶", "gr": "🇬🇷", "gs": "🇬🇸",
    "gt": "🇬🇹", "gu": "🇬🇺", "gw": "🇬🇼", "gy": "🇬🇾", "hk": "🇭🇰",
    "hm": "🇭🇲", "hn": "🇭🇳", "hr": "🇭🇷", "ht": "🇭🇹", "hu": "🇭🇺",
    "id": "🇮🇩", "ie": "🇮🇪", "il": "🇮🇱", "im": "🇮🇲", "in": "🇮🇳",
    "io": "🇮🇴", "iq": "🇮🇶", "ir": "🇮🇷", "is": "🇮🇸", "it": "🇮🇹",
    "je": "🇯🇪", "jm": "🇯🇲", "jo": "🇯🇴", "jp": "🇯🇵", "ke": "🇰🇪",
    "kg": "🇰🇬", "kh": "🇰🇭", "ki": "🇰🇮", "km": "🇰🇲", "kn": "🇰🇳",
    "kp": "🇰🇵", "kr": "🇰🇷", "kw": "🇰🇼", "ky": "🇰🇾", "kz": "🇰🇿",
    "la": "🇱🇦", "lb": "🇱🇧", "lc": "🇱🇨", "li": "🇱🇮", "lk": "🇱🇰",
    "lr": "🇱🇷", "ls": "🇱🇸", "lt": "🇱🇹", "lu": "🇱🇺", "lv": "🇱🇻",
    "ly": "🇱🇾", "ma": "🇲🇦", "mc": "🇲🇨", "md": "🇲🇩", "me": "🇲🇪",
    "mf": "🇲🇫", "mg": "🇲🇬", "mh": "🇲🇭", "mk": "🇲🇰", "ml": "🇲🇱",
    "mm": "🇲🇲", "mn": "🇲🇳", "mo": "🇲🇴", "mp": "🇲🇵", "mq": "🇲🇶",
    "mr": "🇲🇷", "ms": "🇲🇸", "mt": "🇲🇹", "mu": "🇲🇺", "mv": "🇲🇻",
    "mw": "🇲🇼", "mx": "🇲🇽", "my": "🇲🇾", "mz": "🇲🇿", "na": "🇳🇦",
    "nc": "🇳🇨", "ne": "🇳🇪", "nf": "🇳🇫", "ng": "🇳🇬", "ni": "🇳🇮",
    "nl": "🇳🇱", "no": "🇳🇴", "np": "🇳🇵", "nr": "🇳🇷", "nu": "🇳🇺",
    "nz": "🇳🇿", "om": "🇴🇲", "pa": "🇵🇦", "pe": "🇵🇪", "pf": "🇵🇫",
    "pg": "🇵🇬", "ph": "🇵🇭", "pk": "🇵🇰", "pl": "🇵🇱", "pm": "🇵🇲",
    "pn": "🇵🇳", "pr": "🇵🇷", "ps": "🇵🇸", "pt": "🇵🇹", "pw": "🇵🇼",
    "py": "🇵🇾", "qa": "🇶🇦", "re": "🇷🇪", "ro": "🇷🇴", "rs": "🇷🇸",
    "ru": "🇷🇺", "rw": "🇷🇼", "sa": "🇸🇦", "sb": "🇸🇧", "sc": "🇸🇨",
    "sd": "🇸🇩", "se": "🇸🇪", "sg": "🇸🇬", "sh": "🇸🇭", "si": "🇸🇮",
    "sj": "🇸🇯", "sk": "🇸🇰", "sl": "🇸🇱", "sm": "🇸🇲", "sn": "🇸🇳",
    "so": "🇸🇴", "sr": "🇸🇷", "ss": "🇸🇸", "st": "🇸🇹", "sv": "🇸🇻",
    "sx": "🇸🇽", "sy": "🇸🇾", "sz": "🇸🇿", "tc": "🇹🇨", "td": "🇹🇩",
    "tf": "🇹🇫", "tg": "🇹🇬", "th": "🇹🇭", "tj": "🇹🇯", "tk": "🇹🇰",
    "tl": "🇹🇱", "tm": "🇹🇲", "tn": "🇹🇳", "to": "🇹🇴", "tr": "🇹🇷",
    "tt": "🇹🇹", "tv": "🇹🇻", "tw": "🇹🇼", "tz": "🇹🇿", "ua": "🇺🇦",
    "ug": "🇺🇬", "um": "🇺🇲", "us": "🇺🇸", "uy": "🇺🇾", "uz": "🇺🇿",
    "va": "🇻🇦", "vc": "🇻🇨", "ve": "🇻🇪", "vg": "🇻🇬", "vi": "🇻🇮",
    "vn": "🇻🇳", "vu": "🇻🇺", "wf": "🇼🇫", "ws": "🇼🇸", "xk": "🇽🇰",
    "ye": "🇾🇪", "yt": "🇾🇹", "za": "🇿🇦", "zm": "🇿🇲", "zw": "🇿🇼",
    
    # Special cases
    "eu": "🇪🇺", "un": "🇺🇳", "cdn": "🏴",
    "unknown": "🌐", "local": "🏠", "private": "🔒"
}

def lookup_with_singbox(ip: str) -> Tuple[str, str]:
    """Lookup IP info using sing-box binary"""
    if ip in ["localhost", "private", "unknown"]:
        return (ip, ip)
    
    try:
        result = subprocess.run(
            [SING_BOX_PATH, "geoip", "-f", GEOIP_DB_PATH, "lookup", ip],
            capture_output=True,
            text=True,
            timeout=TIMEOUT
        )
        
        if result.returncode != 0:
            print(f"⚠️ sing-box lookup failed for {ip}: {result.stderr}")
            return ("unknown", "unknown")
        
        output = result.stdout.strip().lower()
        
        # Check for CDN matches first
        is_cdn = any(cdn in output for cdn in CDN_CATEGORIES)
        if is_cdn:
            return ("cdn", "cdn")
        
        # Try to extract country code (last 2-letter code in output)
        for code in COUNTRY_EMOJIS:
            if f" {code}" in output or output.endswith(code):
                return (code, code)
        
        return ("unknown", "unknown")
        
    except subprocess.TimeoutExpired:
        print(f"⚠️ sing-box lookup timed out for {ip}")
        return ("unknown", "unknown")
    except Exception as e:
        print(f"⚠️ Error running sing-box for {ip}: {str(e)}")
        return ("unknown", "unknown")

def resolve_ip(domain: str) -> str:
    """Resolve domain to IP with special cases"""
    if not domain:
        return "unknown"
    domain = domain.strip()
    if domain.lower() in ["localhost", "127.0.0.1"]:
        return "localhost"
    if domain.startswith(("10.", "172.16.", "192.168.")):
        return "private"
    try:
        return socket.gethostbyname(domain)
    except (socket.gaierror, socket.timeout):
        return domain

def process_proxies(config: Dict[str, Any]) -> Dict[str, Any]:
    """Process and tag all proxies using sing-box for GeoIP"""
    seen = set()
    results = {
        "total": 0,
        "duplicates": 0,
        "cdn_count": 0,
        "countries": {}
    }

    if "outbounds" not in config:
        print("⚠️ No outbounds found in config")
        return config

    # Collect all proxy tags
    proxy_tags = []

    for proxy in config.get("outbounds", []):
        if proxy.get("type") not in PROXY_TYPES:
            continue

        server = proxy.get("server", "").strip()
        if not server:
            continue
            
        port = proxy.get("server_port", 0)
        ip = resolve_ip(server)

        # Skip duplicates
        proxy_key = (ip, port)
        if proxy_key in seen:
            results["duplicates"] += 1
            continue
        seen.add(proxy_key)

        # Get IP info
        ip_category, country_code = lookup_with_singbox(ip)
        
        # Get appropriate emoji
        emoji = COUNTRY_EMOJIS.get(ip_category, COUNTRY_EMOJIS["unknown"])
        
        proxy["tag"] = f"{emoji} - {server}:{port}"
        proxy_tags.append(proxy["tag"])
        
        # Update stats
        results["total"] += 1
        if ip_category == "cdn":
            results["cdn_count"] += 1
        results["countries"][country_code] = results["countries"].get(country_code, 0) + 1

    # Add all proxy tags to outbounds[1].outbounds if it exists
    if len(config["outbounds"]) > 1 and "outbounds" in config["outbounds"][1]:
        # Sort the proxy_tags alphabetically before adding them
        proxy_tags_sorted = sorted(proxy_tags, key=lambda x: x.lower())
        config["outbounds"][1]["outbounds"] = proxy_tags_sorted
        print(f"\n🔗 Added {len(proxy_tags_sorted)} proxy tags to outbounds[1].outbounds (sorted alphabetically)")

    # Print statistics
    print(f"\n📊 Processing Results:")
    print(f"✅ Total proxies: {results['total']}")
    print(f"🚫 Duplicates removed: {results['duplicates']}")
    print(f"🏴 CDN Proxies: {results['cdn_count']}")
    print("🌍 Countries Detected:")
    for country, count in sorted(results["countries"].items(), key=lambda x: (-x[1], x[0])):
        emoji = COUNTRY_EMOJIS.get(country, "🌐")
        print(f"  {emoji} {country}: {count}")

    return config

def sort_proxies(config: Dict[str, Any]) -> Dict[str, Any]:
    """Sort proxies alphabetically by tag"""
    if "outbounds" not in config or len(config["outbounds"]) < 2:
        return config
    
    # Separate proxies from other outbounds
    proxies: List[Dict[str, Any]] = []
    others: List[Dict[str, Any]] = []
    
    for outbound in config["outbounds"]:
        if outbound.get("type") in PROXY_TYPES:
            proxies.append(outbound)
        else:
            others.append(outbound)
    
    # Sort proxies by tag
    proxies_sorted = sorted(proxies, key=lambda x: x.get("tag", "").lower())
    
    # Rebuild outbounds
    config["outbounds"] = others + proxies_sorted
    return config

def main() -> None:  # Added return type hint
    print("🚀 Starting proxy processor...")

    # Load config
    try:
        with open(CONFIG_PATH, "r", encoding='utf-8') as f:  # Added encoding
            config = json.load(f)
    except FileNotFoundError:
        print(f"❌ Config file not found: {CONFIG_PATH}")
        return
    except json.JSONDecodeError as e:
        print(f"❌ Invalid JSON in config: {e}")
        return
    except Exception as e:
        print(f"❌ Failed to load config: {e}")
        return
    
    # Process proxies
    config = process_proxies(config)
    config = sort_proxies(config)
    
    # Save config
    try:
        with open(CONFIG_PATH, "w", encoding='utf-8') as f:
            json.dump(config, f, separators=(',', ':'), ensure_ascii=False)
        print(f"\n💾 Config saved!")
    except Exception as e:
        print(f"❌ Failed to save config: {e}")

if __name__ == "__main__":
    main()
