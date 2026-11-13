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
| Mercury | mercury-2.5-preview | Hızlı ve en ucuz: küçük düzeltmeler, toplu değişiklikler | $0.04 / $0.15 |
| DeepSeek | deepseek-v4.1-flash-1017 | Zor hatalar | $0.20 / $0.65 |
| Luna Pro | gpt-6-luna-pro | Mantık ağırlıklı kod, ikinci görüş, ekran görüntülü işler | $0.10 / $0.50 |
| Güvenlik | glm-5.3-flash-cybersecurity | Kendi kodunda güvenlik açığı taraması | $0.15 / $0.50 |
| MiniMax | minimax-m3.1-flash | Video kurgu planı | $0.15 / $0.60 |
| Gemma | gemma-4-26b-a4b-it-luminous:free | Senaryo, metin, diyalog | Ücretsiz |

Araçlar: resim üretimi (Routeway, resim başı ~$0.001–0.06), 2D sprite (şeffaf PNG), 3D model (Blender, GLB), seslendirme (edge-tts, ücretsiz), konuşmayı yazıya dökme (Whisper, ücretsiz, bilgisayarda çalışır), video işleme (ffmpeg).

İsteğe bağlı ücretsiz yerel araçlar (`install-ml.ps1`, ~5 GB, NVIDIA ekran kartı önerilir):
- **Müzik** (MusicGen): Arka plan müziği, oyun döngüleri. Lisansı ticari olmayan kullanım içindir (CC-BY-NC 4.0): para kazanılan işlerde kullanılmamalı.
- **Resimden 3D** (TripoSR): Tek bir karakter ya da eşya resminden GLB model üretir.

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
5. İsteğe bağlı: Müzik ve resimden 3D için:
   ```powershell
   powershell -ExecutionPolicy Bypass -File install-ml.ps1
   ```

## Notlar

- İşçiler komut çalıştıramaz. Build, test ve render işlerini Claude yapar ve sonucu kontrol eder.
- Ekipteki tüm modeller test edildi ve çalışıyor. Aşağıdaki 3 model ekipte yok: Routeway tarafında bozuk oldukları için yerlerine başka modeller kullanılıyor (Kasım 2026'da test edildi):

  | Bozuk model | Sorun | Yerine kullanılan |
  |---|---|---|
  | `glm-5.3-flash` | Claude Code'un kullandığı adreste 502 hatası | MiMo (`mimo-v2.6-flash`), neredeyse aynı fiyat |
  | `minimax-m3.1-flash:free` | Routeway'de şu an çalışmıyor | Ücretli sürümü `minimax-m3.1-flash` |
  | `deepseek-v4.1-flash:free` | Routeway'de şu an çalışmıyor | Ücretli sürümü `deepseek-v4.1-flash-1017` |
  | `laguna-s-2.1` | Claude Code'un kullandığı adresi desteklemiyor | MiMo ve Mercury |

  Routeway bunları düzeltirse ekibe geri eklenebilir.
- Loglar `%USERPROFILE%\.claude\cemaat\logs` klasörüne yazılır.
