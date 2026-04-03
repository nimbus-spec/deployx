# VPS è‡ªåŠ¨éƒ¨ç½²å·¥å…·

åŸºäºŽ Unix å“²å­¦çš„æžè‡´è§£è€¦è®¾è®¡ã€‚

## ç›®å½•ç»“æž„

```
vps-deploy/
â”œâ”€â”€ bin/                    # å¯æ‰§è¡Œè„šæœ¬ (æ¯ä¸ªåªåšä¸€ä»¶äº‹)
â”‚   â”œâ”€â”€ detect.sh          # æ£€æµ‹ç¡¬ä»¶
â”‚   â”œâ”€â”€ hostname.sh        # ç”Ÿæˆä¸»æœºå
â”‚   â””â”€â”€ network.sh         # æ£€æµ‹ç½‘ç»œ
â”œâ”€â”€ lib/                   # å‡½æ•°åº“
â”‚   â”œâ”€â”€ output.sh          # è¾“å‡ºå‡½æ•°
â”‚   â”œâ”€â”€ detect.sh          # ç¡¬ä»¶æ£€æµ‹å‡½æ•°
â”‚   â”œâ”€â”€ network.sh         # ç½‘ç»œæ£€æµ‹å‡½æ•°
â”‚   â””â”€â”€ template.sh        # æ¨¡æ¿å¼•æ“Ž
â”œâ”€â”€ templates/             # æ¨¡æ¿æ–‡ä»¶
â”‚   â”œâ”€â”€ user-data.tpl      # Cloud-init ä¸»é…ç½®
â”‚   â”œâ”€â”€ meta-data.tpl      # Meta-data
â”‚   â””â”€â”€ nomad/
â”‚       â”œâ”€â”€ server.hcl.tpl # Nomad Server é…ç½®
â”‚       â””â”€â”€ client.hcl.tpl # Nomad Client é…ç½®
â”œâ”€â”€ config/
â”‚   â””â”€â”€ region-codes.conf  # åŒºåŸŸçŸ­ç æ˜ å°„
â”œâ”€â”€ generate.sh             # ä¸»å…¥å£
â””â”€â”€ README.md
```

## ä½¿ç”¨æ–¹æ³•

```bash
# å…‹éš†æˆ–ä¸‹è½½è„šæœ¬
git clone <repo>
cd vps-deploy

# äº¤äº’å¼ç”Ÿæˆé…ç½®å¹¶å®‰è£…
./generate.sh

# æˆ–å•ç‹¬ä½¿ç”¨å„æ¨¡å—
source lib/output.sh
source lib/detect.sh

# æ£€æµ‹ç¡¬ä»¶
./bin/detect.sh

# æ£€æµ‹ç½‘ç»œ
./bin/network.sh
```

## æ¨¡å—è¯´æ˜Ž

### bin/detect.sh
æ£€æµ‹ç¡¬ä»¶é…ç½®ï¼š
- CPU æ ¸å¿ƒæ•°
- å†…å­˜å¤§å°
- ç£ç›˜å¤§å°

### bin/network.sh
æ£€æµ‹ç½‘ç»œé…ç½®ï¼š
- ç½‘ç»œç±»åž‹ (v4/v6/nat/dual)
- IP åœ°å€
- ç½‘å…³
- DNS

### bin/hostname.sh
ç”Ÿæˆæ ‡å‡†æ ¼å¼ä¸»æœºåï¼š
```
{å›½å®¶}-{åŒºåŸŸ}-{ç½‘ç»œç±»åž‹}-{å•†å®¶}-{éšæœº8ä½}
ä¾‹: jp-tyo-v4-oracle-a1b2c3d4
```

### lib/output.sh
ç»Ÿä¸€è¾“å‡ºå‡½æ•°ï¼š
- `info` - ä¿¡æ¯
- `success` - æˆåŠŸ
- `warn` - è­¦å‘Š
- `error` - é”™è¯¯
- `header` - æ ‡é¢˜
- `confirm` - ç¡®è®¤æç¤º

## è‡ªå®šä¹‰é…ç½®

### æ·»åŠ åŒºåŸŸæ˜ å°„
ç¼–è¾‘ `config/region-codes.conf`ï¼š
```bash
declare -A REGION_CODES=(
    ["tokyo"]="tyo"
    ["shanghai"]="sha"
)
```

### è‡ªå®šä¹‰ Nomad é…ç½®
ç¼–è¾‘ `templates/nomad/server.hcl.tpl` æˆ– `client.hcl.tpl`

## æ¨¡æ¿å˜é‡

| å˜é‡ | è¯´æ˜Ž |
|------|------|
| `{{ HOSTNAME }}` | ä¸»æœºå |
| `{{ SSH_PORT }}` | SSH ç«¯å£ |
| `{{ SSH_KEY }}` | SSH å…¬é’¥ |
| `{{ PASSWORD_HASH }}` | å¯†ç å“ˆå¸Œ |
| `{{ NOMAD_ROLE }}` | Nomad è§’è‰² |
| `{{ NETWORK_CONFIG }}` | ç½‘ç»œé…ç½® |
| `{{ RUNCMD }}` | å®‰è£…åŽå‘½ä»¤ |

## ä¾èµ–

- Linux (bash)
- cloud-init
- openssl (å¯†ç å“ˆå¸Œ)
- curl (ä¸‹è½½)

## License

MIT
