# AtlasOS product website

This is the static public-facing product site, built with Astro. It is deliberately separate from the AtlasOS runtime and release build. It contains no ISO artifacts. Product screenshots are genuine AtlasOS captures; the optimized 0.6.3 RC desktop image was captured from the actual Live desktop in QEMU/OVMF at 1920 × 1080 and converted to WebP without changing its interface content.

## Local development

```sh
npm ci
npm run build
npm run check
```

The generated site is written to `website/dist/`. The smoke check verifies English and Turkish routes, local links/images, language metadata, authentic gallery captures, page landmarks and titles, local-path leaks, and absence of OS image artifacts.

## GitHub Pages

The `Website / GitHub Pages` workflow builds this directory and deploys only `website/dist/` on pushes to `main`. Pull requests build and validate the site without deploying it. The project site URL is `https://chavooosss.github.io/AtlasOS/`.

If Pages has not been enabled for this repository, open **Settings → Pages → Build and deployment → Source** and select **GitHub Actions**. No custom domain is configured.

The download page intentionally distinguishes public source availability from binary release status. It must be updated only after an approved GitHub Release exists.
