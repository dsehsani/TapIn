# To-Do: Article TLDR Bullets

## Plan
- [x] Backend: `claude_service.py` — add `generate_article_tldr()` + `_tldr_cache`
- [x] Backend: `api/articles.py` — generate TLDR on cache miss before saving
- [x] iOS: `ArticleContent.swift` — add `tldrBullets: [String]`
- [x] iOS: `NewsService.swift` — decode `tldrBullets` in `BackendArticleContent`
- [x] iOS: `ArticleCacheService.swift` — add `tldrBullets` to `CachedArticleContent`
- [x] iOS: `AggieArticleParser.swift` — pass empty `tldrBullets` in fallback construction
- [x] iOS: `ArticleDetailView.swift` — add `ArticleTLDRCard` + `ArticleTLDRBullet`, render above body
- [x] Verify: backend syntax check passes

## Results
- Backend: `generate_article_tldr()` uses Haiku, first 4 paragraphs only, cached in `_tldr_cache`
- Backend: TLDR generated on cache miss in `GET /api/articles/content`, stored permanently in Firestore
- iOS: `tldrBullets` flows through all 4 construction sites (backend response, disk cache, parser fallback, model)
- iOS: `ArticleTLDRCard` renders above body paragraphs with bold label parsing
- Legacy articles without `tldrBullets` gracefully show no card (empty array fallback)
