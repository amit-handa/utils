# Current Workstation Inventory

**Generated:** 2026-08-14 UTC
**Platform:** macos

Observed state only. Desired setup remains curated in `manifests/`.

## Applications and IDEs

| Tool | Status | Evidence | Desired profile |
| --- | --- | --- | --- |
| IntelliJ IDEA | detected | application:IntelliJ IDEA | base |
| Visual Studio Code | detected | command:code | base |
| Cursor | detected | command:cursor | base |
| Neovim | detected | command:nvim | base |
| Vim | detected | command:vim | base |

## CLI and shells

| Tool | Status | Evidence | Desired profile |
| --- | --- | --- | --- |
| Git | detected | command:git | base |

## Terminal and session utilities

| Tool | Status | Evidence | Desired profile |
| --- | --- | --- | --- |
| Herdr | detected | command:herdr | work |
| Ghostty | detected | application:Ghostty | base@macos&#124;base@linux |
| tmux | detected | command:tmux | base |
| Hammerspoon | detected | application:Hammerspoon | base@macos |

## AI tools

| Tool | Status | Evidence | Desired profile |
| --- | --- | --- | --- |
| Oh My Pi | detected | command:omp | base |
| Claude Code | detected | command:claude | base |
| Codex | detected | config:$HOME/.codex | base |
| GitHub Copilot | detected | config:$HOME/.config/github-copilot | base |

## Developer and cloud tools

| Tool | Status | Evidence | Desired profile |
| --- | --- | --- | --- |
| Homebrew | detected | command:brew | base@macos |
| npm | detected | command:npm | base |
| Devbox | detected | command:devbox | work |
| Teleport CLI | detected | command:tsh | work |
| kubectl | detected | command:kubectl | work |
| Bazel | detected | command:bazel | work |
| GitHub CLI | detected | command:gh | work |

## Language and mobile stacks

| Tool | Status | Evidence | Desired profile |
| --- | --- | --- | --- |
| Android tooling | detected | command:adb; version:android=Android Debug Bridge version 1.0.41 | mobile |
| Xcode and simulators | detected | command:xcodebuild; version:xcode=Xcode 26.6 | mobile@macos |
| Java and jenv | detected | command:java; version:java=openjdk version 17.0.20 2026-07-21 LTS; jenv=jenv 0.6.0 | base |
| Go | detected | command:go; version:go=go version go1.26.5 darwin/arm64 | base |
| Python | detected | command:python3; version:python=Python 3.14.7 | base |
| Node and Bun | detected | command:node; version:node=v26.7.0; bun=1.3.14 | base |

## Package manager inventory

| Source | Package | Version | Desired profile |
| --- | --- | --- | --- |
| cask | alt-tab | 11.4.4 | observed-only |
| cask | android-platform-tools | 37.0.1 | mobile |
| cask | charles | 5.2.1 | observed-only |
| cask | connectiq-sdk-manager | 1.0.16 | observed-only |
| cask | corretto@11 | 11.0.32.9.1 | observed-only |
| cask | corretto@17 | 17.0.20.8.1 | observed-only |
| cask | corretto@21 | 21.0.12.8.1 | observed-only |
| cask | font-meslo-lg-nerd-font | 3.5.0 | observed-only |
| cask | ghostty | 1.2.3 | base |
| cask | gimp | 3.2.4 | observed-only |
| cask | maccy | 2.7.1 | observed-only |
| cask | notunes | 3.5 | observed-only |
| cask | stats | 3.0.11 | observed-only |
| cask | stremio | 5.1.26 | observed-only |
| formula | abseil | 20260526.0 | observed-only |
| formula | ada-url | 4.0.0 | observed-only |
| formula | autoconf | 2.73 | observed-only |
| formula | av | 0.1.45 | observed-only |
| formula | aws-c-auth | 0.10.4 | observed-only |
| formula | aws-c-cal | 0.9.15 | observed-only |
| formula | aws-c-common | 0.14.5 | observed-only |
| formula | aws-c-compression | 0.3.2 | observed-only |
| formula | aws-c-event-stream | 0.7.1 | observed-only |
| formula | aws-c-http | 0.11.0 | observed-only |
| formula | aws-c-io | 0.27.6 | observed-only |
| formula | aws-c-mqtt | 0.16.1 | observed-only |
| formula | aws-c-s3 | 0.13.5 | observed-only |
| formula | aws-c-sdkutils | 0.2.9 | observed-only |
| formula | aws-checksums | 0.2.10 | observed-only |
| formula | awscli | 2.36.22 | observed-only |
| formula | bazelisk | 1.29.0 | work |
| formula | bk@3 | 3.54.2 | observed-only |
| formula | brotli | 1.2.0 | observed-only |
| formula | buildifier | 8.5.1 | observed-only |
| formula | buildkit | 0.32.2 | observed-only |
| formula | bun | 1.3.14 | base |
| formula | c-ares | 1.34.8 | observed-only |
| formula | ca-certificates | 2026-08-13 | observed-only |
| formula | cairo | 1.18.4 | observed-only |
| formula | certifi | 2026.7.22 | observed-only |
| formula | cffi | 2.1.1 | observed-only |
| formula | cryptography | 50.0.0 | observed-only |
| formula | duti | 1.5.4_1 | observed-only |
| formula | envoy | 1.39.0 | observed-only |
| formula | fastlane | 2.238.0 | observed-only |
| formula | fmt | 12.2.0 | observed-only |
| formula | fontconfig | 2.18.3 | observed-only |
| formula | freetype | 2.14.3 | observed-only |
| formula | fribidi | 1.0.16 | observed-only |
| formula | fzf | 0.74.2 | observed-only |
| formula | gettext | 1.0 | observed-only |
| formula | gh | 2.97.0 | work |
| formula | giflib | 6.1.3 | observed-only |
| formula | git | 2.55.0 | base |
| formula | git-lfs | 3.7.1 | observed-only |
| formula | glib | 2.88.3 | observed-only |
| formula | gmp | 6.3.0 | observed-only |
| formula | gnupg | 2.5.21 | observed-only |
| formula | gnutls | 3.8.13_2 | observed-only |
| formula | go | 1.26.5 | base |
| formula | googleworkspace-cli | 0.22.5 | observed-only |
| formula | gpgme | 2.1.2 | observed-only |
| formula | gpgmepp | 2.1.0 | observed-only |
| formula | graphite2 | 1.3.15 | observed-only |
| formula | grep | 3.12 | observed-only |
| formula | grpcurl | 1.9.3 | observed-only |
| formula | harfbuzz | 14.3.1 | observed-only |
| formula | hdrhistogram_c | 0.11.10 | observed-only |
| formula | helm | 4.2.3 | observed-only |
| formula | herdr | 0.8.0 | work |
| formula | htop | 3.5.2 | observed-only |
| formula | icu4c@78 | 78.3 | observed-only |
| formula | jenv | 0.6.0 | base |
| formula | jpeg-turbo | 3.2.0 | observed-only |
| formula | jq | 1.8.2 | observed-only |
| formula | json-c | 0.19 | observed-only |
| formula | kotlin-lsp | 262.9593.0 | observed-only |
| formula | leptonica | 1.87.0 | observed-only |
| formula | libarchive | 3.8.9 | observed-only |
| formula | libassuan | 3.0.2 | observed-only |
| formula | libb2 | 0.98.1 | observed-only |
| formula | libdatrie | 0.2.14 | observed-only |
| formula | libevent | 2.1.13 | observed-only |
| formula | libffi | 3.8.0 | observed-only |
| formula | libgcrypt | 1.12.2 | observed-only |
| formula | libgpg-error | 1.61 | observed-only |
| formula | libidn2 | 2.3.8 | observed-only |
| formula | libksba | 1.8.0 | observed-only |
| formula | libnghttp2 | 1.70.0 | observed-only |
| formula | libnghttp3 | 1.18.0 | observed-only |
| formula | libngtcp2 | 1.25.0 | observed-only |
| formula | libpng | 1.6.58 | observed-only |
| formula | libtasn1 | 4.21.0 | observed-only |
| formula | libthai | 0.1.30 | observed-only |
| formula | libtiff | 4.7.2 | observed-only |
| formula | libunistring | 1.4.2 | observed-only |
| formula | libusb | 1.0.30 | observed-only |
| formula | libuv | 1.52.1 | observed-only |
| formula | libx11 | 1.8.13 | observed-only |
| formula | libxau | 1.0.12 | observed-only |
| formula | libxcb | 1.17.0 | observed-only |
| formula | libxdmcp | 1.1.5 | observed-only |
| formula | libxext | 1.3.7 | observed-only |
| formula | libxrender | 0.9.12 | observed-only |
| formula | libyaml | 0.2.5 | observed-only |
| formula | little-cms2 | 2.19 | observed-only |
| formula | llhttp | 9.4.3 | observed-only |
| formula | lpeg | 1.1.0_2 | observed-only |
| formula | luajit | 2.1.1785763465 | observed-only |
| formula | luv | 1.52.1-0 | observed-only |
| formula | lz4 | 1.10.0 | observed-only |
| formula | lzo | 2.10 | observed-only |
| formula | m4 | 1.4.21 | observed-only |
| formula | merve | 1.2.2_1 | observed-only |
| formula | mise | 2026.8.5 | observed-only |
| formula | mpdecimal | 4.0.1 | observed-only |
| formula | nbytes | 0.1.4 | observed-only |
| formula | ncurses | 6.6 | observed-only |
| formula | neovim | 0.12.4 | base |
| formula | nettle | 4.0 | observed-only |
| formula | node | 26.7.0 | base |
| formula | npth | 1.8 | observed-only |
| formula | nspr | 4.40 | observed-only |
| formula | nss | 3.126 | observed-only |
| formula | omp | 17.3.0 | base |
| formula | oniguruma | 6.9.10 | observed-only |
| formula | opencode | 1.18.18 | observed-only |
| formula | openjpeg | 2.5.4 | observed-only |
| formula | openssl@3 | 3.6.3 | observed-only |
| formula | p11-kit | 0.26.5 | observed-only |
| formula | pandoc | 3.10.2 | observed-only |
| formula | pango | 1.58.2 | observed-only |
| formula | parallel | 20260722 | observed-only |
| formula | pcre2 | 10.47_1 | observed-only |
| formula | pinentry | 1.3.3 | observed-only |
| formula | pipx | 1.16.6 | observed-only |
| formula | pixman | 0.46.4 | observed-only |
| formula | pkgconf | 3.0.5 | observed-only |
| formula | poppler | 26.08.0 | observed-only |
| formula | popt | 1.19 | observed-only |
| formula | pre-commit | 4.6.2 | observed-only |
| formula | protobuf | 35.1_1 | observed-only |
| formula | pstree | 2.40 | observed-only |
| formula | pycparser | 3.0 | observed-only |
| formula | pydantic | 2.13.4 | observed-only |
| formula | pyenv | 2.8.4 | observed-only |
| formula | python@3.13 | 3.13.15 | base |
| formula | python@3.14 | 3.14.7 | base |
| formula | rbenv | 1.3.2 | observed-only |
| formula | readline | 8.3.3 | observed-only |
| formula | ripgrep | 15.2.0 | observed-only |
| formula | rsync | 3.4.4 | observed-only |
| formula | ruby | 4.0.6 | observed-only |
| formula | ruby-build | 20260716 | observed-only |
| formula | s2n | 1.7.7 | observed-only |
| formula | simdjson | 4.6.6 | observed-only |
| formula | simdutf | 9.0.0 | observed-only |
| formula | snowflake-cli | 3.24.1 | observed-only |
| formula | sponge | 0.70 | observed-only |
| formula | sqlite | 3.53.4 | observed-only |
| formula | sshuttle | 1.3.2 | observed-only |
| formula | stern | 1.34.0 | observed-only |
| formula | telnet | 308 | observed-only |
| formula | terminal-notifier | 2.0.0 | observed-only |
| formula | tesseract | 5.5.3 | observed-only |
| formula | tfenv | 3.2.2 | observed-only |
| formula | tmux | 3.7b | base |
| formula | tree-sitter | 0.26.12 | observed-only |
| formula | tree-sitter-cli | 0.26.12 | observed-only |
| formula | unibilium | 2.1.2 | observed-only |
| formula | usage | 5.1.0 | observed-only |
| formula | utf8proc | 2.11.3 | observed-only |
| formula | uv | 0.12.3 | observed-only |
| formula | uvwasi | 0.0.23 | observed-only |
| formula | vault | 2.0.3 | observed-only |
| formula | webp | 1.6.0 | observed-only |
| formula | wget | 1.25.0 | observed-only |
| formula | xorgproto | 2025.1 | observed-only |
| formula | xxhash | 0.8.3 | observed-only |
| formula | xz | 5.8.3 | observed-only |
| formula | zstd | 1.5.7_1 | observed-only |
| go-bin | api-linter | - | observed-only |
| go-bin | dlv | - | observed-only |
| go-bin | gopls | - | observed-only |
| go-bin | protoc-gen-doc | - | observed-only |
| go-bin | protoc-gen-go | - | observed-only |
| go-bin | protoc-gen-go-grpc | - | observed-only |
| go-bin | protoc-gen-grpc-gateway | - | observed-only |
| go-bin | protoc-gen-swagger | - | observed-only |
| npm | @earendil-works/pi-coding-agent | 0.82.0 | base |
| npm | @mermaid-js/mermaid-cli | 11.16.0 | observed-only |
| npm | npm | 11.19.0 | base |

## Configuration sources

| Source | Status | Safe fingerprint | Desired profile |
| --- | --- | --- | --- |
| utils-revision | present | 8ec2a3d8ac5ec6f72adb4c9596af8ca4d5fa9d92 | source |
| zshrc | present | 5f6f7fd949ae767f0bfe7b989afb173770367764904b999628eccefa3de172af | base |
| bashrc | present | 89daee9db6959efe49b4a0c005210d5e851078b2d16cdc67296721515e8d5c70 | base |
| gitconfig | manual-review | - | base |
| gitconfig-local | local-missing | - | base |
| tmux | present | a2e2c13df13437839ee31624281d66db847ceee7b871c293b7fd1ab4ab6bc176 | base |
| ghostty-macos | present | 1aa24c392e1909ec510090db43d0cfb2322810da77c1fdea12e6792c5b1fba12 | base@macos |
| nvim-custom | directory-present | 8ec2a3d8ac5ec6f72adb4c9596af8ca4d5fa9d92 | base |
| kubectl-aliases | present | 2aa25534691f3f2ba672de907ee9781581641c3991412e8bb34e461d1718d36f | work |
| hammerspoon | directory-present | 8ec2a3d8ac5ec6f72adb4c9596af8ca4d5fa9d92 | base@macos |
| hammerspoon:init.lua | present | f8fbc67f3601ebd4f154c5272e8a9fff0b6ec2b2f4a8c25e4a31394af32b358e | base@macos |
| hammerspoon:keyboard/control-escape.lua | present | 7b84f58d9060c518a69e36789f63665d35967a22e40a5e523ac040f502aa4e35 | base@macos |
| hammerspoon:keyboard/delete-words.lua | present | c01dce9f1b23977a6be1e0585b3934af58ed2ddc64135661f3cb83b672bb2b94 | base@macos |
| hammerspoon:keyboard/hyper-apps-defaults.lua | present | 3a1cbbadfc072078eadaf5b09f8cdc86757af2ba693acea870c59e75cbe840a5 | base@macos |
| hammerspoon:keyboard/hyper.lua | present | 894e5f2da39328398c00c8196f069b22c76b6116eb5f8974ff25aafb90f10f37 | base@macos |
| hammerspoon:keyboard/init.lua | present | 38fe745a0330d73fae6bf6fd852b108e6902da3282d57856a4c14f3f2807611a | base@macos |
| hammerspoon:keyboard/markdown.lua | present | efad53bb805678e0b71bae58d7a2ba9cdc8155603d1636a089a32406961b3c4a | base@macos |
| hammerspoon:keyboard/microphone.lua | present | 579c17abe148244897035592f9b65cf98e4ec7051c11f5549c6d759a93206d9e | base@macos |
| hammerspoon:keyboard/panes.lua | present | 2152a6621531ba0db3e7c188ed5061c721c531373296cb0b7b683c817a8377b3 | base@macos |
| hammerspoon:keyboard/spaces.lua | present | f90fbab565f122a734ae85aa02420a7c83b86cfca7b0b22781d662f9b705105c | base@macos |
| hammerspoon:keyboard/status-message.lua | present | 1906703704c8cc2e935c53f48c49c87e9f63b772873e6e1d2a90e59d203cd640 | base@macos |
| hammerspoon:keyboard/windows-bindings-defaults.lua | present | ae9198f69d05c2c0cd7aa4f7c642ea5bb1d78263280f62d10e854c08db7bede9 | base@macos |
| hammerspoon:keyboard/windows.lua | present | 9bc114f521ce1fec7059d9e987a57a0742f0149f93be9e20178bb3fcaf11f490 | base@macos |
| hammerspoon:winlayout/init.lua | present | fde39fa8588c98b66b204579bddb4ce93218a5746b0efadd7f2e01a35f35a2cb | base@macos |
| hammerspoon:Spoons/Ki.spoon/init.lua | present | 186ecbee88ab0eb4ce8f44fdc790ba40cd0fd16b38c157d1f2381333e7adc551 | base@macos |
| hammerspoon:Spoons/Lunette.spoon/init.lua | present | c162f1e40619267ba8e2fc1b854945e0d9dfb7e71bb57050382a509ab75e0035 | base@macos |

## Recent usage

| Status | Normalized date/name rows | Detail |
| --- | ---: | --- |
| available | 110 | See `recent-usage.md`; no raw commands retained. |

## Unclassified

| Source | Name | Desired profile |
| --- | --- | --- |
| application | Alfred 5 | observed-only |
| application | AltTab | observed-only |
| application | Charles | observed-only |
| application | ChatGPT | observed-only |
| application | Claude Code URL Handler | observed-only |
| application | Cortex XDR | observed-only |
| application | Firefox | observed-only |
| application | GIMP | observed-only |
| application | Glean | observed-only |
| application | Google Chrome | observed-only |
| application | Google Docs | observed-only |
| application | Google Drive | observed-only |
| application | Google Sheets | observed-only |
| application | Google Slides | observed-only |
| application | Handy | observed-only |
| application | JetBrains Gateway | observed-only |
| application | JetBrains Toolbox | observed-only |
| application | Kreya | observed-only |
| application | LibreOffice | observed-only |
| application | Mac Evaluation Utility | observed-only |
| application | Maccy | observed-only |
| application | Managed Software Center | observed-only |
| application | Microsoft Word | observed-only |
| application | OmniDiskSweeper | observed-only |
| application | OrbStack | observed-only |
| application | Postman | observed-only |
| application | Proxyman | observed-only |
| application | RedStudio | observed-only |
| application | Safari | observed-only |
| application | Santa | observed-only |
| application | SdkManager | observed-only |
| application | Self-Service | observed-only |
| application | Slack | observed-only |
| application | Stats | observed-only |
| application | Stremio | observed-only |
| application | Support | observed-only |
| application | Syncthing | observed-only |
| application | Tailscale | observed-only |
| application | WeChat | observed-only |
| application | Xcode-26.6.0 | observed-only |
| application | Xcode.26.3 | observed-only |
| application | Zed | observed-only |
| application | Zoom | observed-only |
| application | cmux | observed-only |
| application | noTunes | observed-only |
| application | tctl | observed-only |
| application | tsh | observed-only |

Unknown normalized commands are retained in `recent-usage.md`.
