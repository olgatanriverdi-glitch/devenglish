# DevEnglish

Yazılım mühendisliği öğrencileri için kişisel İngilizce çalışma uygulaması (Flutter: web + iOS + Android).

| Bölüm | Ne yapar |
|---|---|
| **Kelime** | 1000+ yazılım/mühendislik kelimesi (18 alan: programlama, veri yapıları, web, veritabanı, DevOps, test, süreç, mimari, güvenlik, Git, ağ/işletim sistemi, arayüz/UX, mobil, oyun, yapay zeka, iş hayatı, genel mühendislik…). Yeni kelime tanıtma + aralıklı tekrar (Leitner: 1-3-7-16-35 gün). Çoktan seçmeli, boşluk doldurma, dinleyip yazma, kart çevirme. |
| **Dinle** | 15 diyalog/konuşma (A2–B2) + anlama soruları; yavaş mod; metin gizli dinleme. Dikte (60 cümle). |
| **Konuş** | Cümle okuma (sözcük sözcük puan), 22 mülakat/iş sorusuna sesli cevap (anahtar kelime puanı + örnek cevap), 40 zor kelimede telaffuz (IPA + Türkçe ipucu). |
| **Oku** | 26 özgün kısa makale (kelimelere dokununca Türkçesi, sesli dinleme, anlama soruları) + 18 güvenilir site bağlantısı. |

İlerleme (seri, XP, tekrar planı) cihazda saklanır; sunucu yok.

## Çalıştırma
```bash
flutter pub get
flutter test
flutter run -d chrome        # web
flutter run                  # bağlı telefon
```
Konuşma tanıma: iPhone'da Mikrofon + Konuşma Tanıma izni, web'de Chrome/Safari ve mikrofon izni gerekir. Sesler önceden kaydedilmiştir (Samantha ve Daniel), böylece Türkçe telefonlarda bile doğru İngilizce telaffuz duyulur; kaydı olmayan metinlerde cihazın sesi kullanılır.

## İçeriği düzenleme
Kaynaklar `tools/` altında: `vocab.txt` (kelimeler), `content_listening.py`, `content_speaking.py`, `content_articles.py`.
```bash
python3 tools/build_vocab.py      # assets/data/vocab.json
python3 tools/build_content.py    # listening / speaking / articles .json (+ doğrulama)
python3 tools/make_icons.py       # uygulama simgeleri
python3 tools/make_audio.py       # tüm İngilizce metinlerin ses kayıtları (macOS `say`: Samantha + Daniel) -> assets/audio
```

## Web olarak yayınlama (GitHub Pages)
1. GitHub'da `devenglish` adında depo oluştur, bu klasörü gönder.
2. Depo → Settings → Pages → Source: **GitHub Actions**.
3. Adres: `https://<kullanıcı>.github.io/devenglish/`. iPhone'da Safari → Paylaş → **Ana Ekrana Ekle** ile uygulama gibi kurulur.

## iPhone'a doğrudan kurulum
`ios/Runner.xcworkspace` dosyasını Xcode'da aç → Runner → Signing & Capabilities → Team'i seç (bir kez), sonra `flutter run` ya da `flutter build ios`. Ücretsiz Apple hesabında uygulama 7 günde bir yeniden kurulmalıdır.
