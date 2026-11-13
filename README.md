# Cemaat

Claude Code için çok modelli ajan ekibi. Claude (orkestratör) görevi planlar, işi ucuz yapay zeka modellerine dağıtır, sonucu kontrol eder ve teslim eder.

```
/cemaat <görev>
```

## Ekip

| Ajan | Model | İş | Fiyat (1M token, giriş/çıkış) |
|---|---|---|---|
| Orkestratör | Claude (senin planın) | Plan, kontrol, teslim | Claude planın |
| MiMo | mimo-v2.6-flash | Kod, oyun, eklenti, motion grafik, 3D script | $0.14 / $0.28 |
| DeepSeek | deepseek-v4.1-flash-1017 | Zor hatalar, ikinci görüş | $0.20 / $0.65 |
| MiniMax | minimax-m3.1-flash | Video kurgu planı | $0.15 / $0.60 |
| Gemma | gemma-4-26b-a4b-it-luminous:free | Senaryo, metin, diyalog | Ücretsiz |

Araçlar: resim üretimi (Routeway, resim başı ~$0.001–0.06), 2D sprite (şeffaf PNG), 3D model (Blender, GLB), seslendirme (edge-tts, ücretsiz), video işleme (ffmpeg).

## Maliyet

Herkes kendi hesabını kullanır, kimse kimsenin hesabından harcamaz.

- **Claude:** Claude Code kullanabilen bir Claude planı (ör. Pro) gerekir.
- **Routeway:** Ücretli işçiler ve resim üretimi için bakiye gerekir. Deneme için $2–5 yeterlidir. Ücretsiz Gemma, bakiye olmadan da çalışır.
- **Diğer araçlar** (ffmpeg, Blender, edge-tts, rembg) ücretsizdir.

## Kurulum (Windows)

1. Araçları kur: Bu repoyu indir ve PowerShell'de çalıştır:
   ```powershell
   powershell -ExecutionPolicy Bypass -File install-tools.ps1
   ```
2. Routeway key: [routeway.ai](https://routeway.ai) üzerinden bir API key al. Kendi key'inle çalıştır:
   ```powershell
   [Environment]::SetEnvironmentVariable("ROUTEWAY_API_KEY", "senin-key", "User")
   ```
   Key'ini kimseyle paylaşma ve hiçbir dosyaya yazma.
3. Eklentiyi ekle: Claude Code'da:
   ```
   /plugin marketplace add musabakif/cemaat-plugin
   /plugin install cemaat@cemaat
   ```
4. Claude uygulamasını tamamen kapatıp yeniden aç.

## Notlar

- İşçiler komut çalıştıramaz. Build, test ve render işlerini Claude yapar ve sonucu kontrol eder.
- Routeway'de `/v1/messages` adresinde bazı modeller 502 hatası veriyor: `glm-5.3-flash`, `minimax-m3.1-flash:free`, `deepseek-v4.1-flash:free`. Bunlar devre dışı.
- Loglar `%USERPROFILE%\.claude\cemaat\logs` klasörüne yazılır.
