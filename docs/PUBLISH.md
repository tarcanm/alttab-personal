# Public'e çevirme adımları (test sonrası, tek seferde)

Karar (19 Eyl 2026): **MIT lisans** + **test sonrası public**.

Hazırlık bu commit'te tamamlandı: `LICENSE` (MIT), public'e uygun `README.md` (İngilizce),
`Info.plist` telif metni güncellendi. Yani public'e çevirmek için kod tarafında bekleyen iş yok.

## Flip (2 API çağrısı)

```bash
TOKEN=<github_token>
# 1) Issues kapalı olsun (destek yükü olmasın)
curl -s -X PATCH -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
  -d '{"has_issues":false,"has_wiki":false,"has_discussions":false,"description":"Windows-style ⌥+Tab window switcher for macOS. Written from scratch in Swift/AppKit. MIT."}' \
  https://api.github.com/repos/tarcanm/alttab-personal

# 2) Public yap
curl -s -X PATCH -H "Authorization: token $TOKEN" -H "Accept: application/vnd.github+json" \
  -d '{"private":false}' \
  https://api.github.com/repos/tarcanm/alttab-personal
```

Sonra doğrula:

```bash
curl -s -H "Authorization: token $TOKEN" https://api.github.com/repos/tarcanm/alttab-personal \
  | python3 -c "import sys,json;d=json.load(sys.stdin);print(d['full_name'], 'private:', d['private'], 'issues:', d['has_issues'])"
```

## Flip öncesi kontrol listesi

- [ ] MacBook'ta `make app` hatasız derlendi
- [ ] `⌥ + Tab` çalışıyor, seçim doğru pencereyi öne getiriyor
- [ ] README'deki adımlar gerçekten işe yarıyor (klon → derleme → izin → test)
- [ ] Repo'da secret yok (19 Eyl taraması: temiz)
- [ ] `docs/PLAN.md` ve kod yorumları Türkçe; public repo'da sorun değil ama istenirse İngilizce'ye çevrilebilir

## Flip sonrası (opsiyonel)

- Repo başlığına kısa açıklama + varsa ekran görüntüsü/GIF ekle (README'ye `![demo](docs/demo.gif)`)
- GitHub Release: `v0.1.0` etiketi + not (kaynak kod olarak; imzasız .app dağıtımı yapmıyoruz)
- README'ye "kendi geliştirici sertifikanla imzalama" bölümü (TCC izni kalıcı olsun diye)
