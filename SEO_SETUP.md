# Mooziac Google Search & SEO Setup Guide

This guide walks you through every step to ensure **Mooziac** is properly indexed, discovered, and ranked on Google Search for keywords such as:
- `Mooziac`
- `Mooziac macOS`
- `Mooziac music player`
- `Mooziac GitHub`
- `Mooziac YouTube Music`

---

## 1. GitHub Repository Configuration

To maximize discoverability of the official GitHub repository (`https://github.com/shirkeharsh/mooziac`):

### A. Set Repository Description
1. Go to [github.com/shirkeharsh/mooziac](https://github.com/shirkeharsh/mooziac).
2. On the right-hand sidebar under **About**, click the ⚙️ (gear icon).
3. Set the **Description** to:
   ```
   Mooziac — A beautiful native macOS music player built with Swift and SwiftUI.
   ```
4. Set the **Website** field to:
   ```
   https://mooziac.threeten.site
   ```

### B. Add Repository Topics
Under the same **About** settings, add the following 8 topics:
- `mooziac`
- `macos`
- `macos-app`
- `music-player`
- `youtube-music`
- `swift`
- `swiftui`
- `native-macos`

Click **Save changes**.

---

## 2. GitHub Pages Deployment

The static landing page is stored in the `docs/` folder of this repository with automated deployment workflows.

### Option A: Via GitHub Pages Settings (Standard)
1. In your GitHub repository, go to **Settings** > **Pages**.
2. Under **Build and deployment**:
   - **Source:** Select `Deploy from a branch`.
   - **Branch:** Select `main` and folder `/docs`.
   - Click **Save**.
3. Under **Custom domain**:
   - Enter `mooziac.threeten.site` (saved in `docs/CNAME`).
   - Check **Enforce HTTPS** (once DNS certificates are provisioned).

### Option B: Via GitHub Actions Workflow
- A GitHub Actions workflow is provided in `.github/workflows/pages.yml`.
- In **Settings** > **Pages**, under **Source**, you can select `GitHub Actions`.

---

## 3. Google Search Console Setup & Ownership Verification

Google Search Console allows you to monitor search performance, submit sitemaps, and inspect Googlebot crawl status.

### Step 1: Add Property to Search Console
1. Navigate to [Google Search Console](https://search.google.com/search-console).
2. Sign in with your Google account.
3. Click **Add Property** in the top-left dropdown.
4. You will see two options:
   - **Domain property** (`threeten.site`): Covers all subdomains (`mooziac.threeten.site`, etc.).
   - **URL prefix property** (`https://mooziac.threeten.site/`): Recommended for dedicated single-site verification.

### Step 2: Verify Site Ownership
Choose one of the following verification methods:

- **Method 1: DNS TXT Record (Best for Domain property)**
  1. Copy the Google verification TXT record (e.g. `google-site-verification=...`).
  2. Log into your DNS provider (Cloudflare, Namecheap, Route53, etc.) for `threeten.site`.
  3. Add a TXT record with Host `@` (or `mooziac`) and the verification string.
  4. Return to Search Console and click **Verify**.

- **Method 2: HTML Meta Tag (Quick for URL prefix)**
  1. Copy the `<meta name="google-site-verification" content="..." />` tag from Search Console.
  2. Paste it inside the `<head>` section of `docs/index.html`.
  3. Push to `main`.
  4. Click **Verify** in Search Console.

- **Method 3: HTML File Upload**
  1. Download the verification file (e.g. `google123456789.html`).
  2. Place it in `docs/` and commit/push.
  3. Click **Verify**.

---

## 4. Submit `sitemap.xml`

Once ownership is verified:
1. In Search Console, click **Sitemaps** from the left navigation.
2. In the **Add a new sitemap** input, enter:
   ```
   sitemap.xml
   ```
   (Full URL: `https://mooziac.threeten.site/sitemap.xml`)
3. Click **Submit**.
4. You should see a status of **Success**. Googlebot will periodically poll this file to discover updated content.

---

## 5. Request Indexing using the URL Inspection Tool

To alert Googlebot to crawl and index your homepage immediately:

1. Click on the search bar at the top of Search Console labeled **"Inspect any URL in 'https://mooziac.threeten.site/'"**.
2. Enter:
   ```
   https://mooziac.threeten.site/
   ```
   and press Enter.
3. Click the **Test Live URL** button in the top right to verify that Googlebot can fetch the page without errors.
4. Click **Request Indexing**.
5. Google will add the URL to its priority crawl queue.

---

## 6. How to Check Indexing Status

- **URL Inspection Tool:** Enter `https://mooziac.threeten.site/` at any time to check if the URL is on Google, when it was last crawled, and which canonical URL Google selected.
- **Pages Report (Coverage):** In Search Console > **Pages**, review indexed vs not indexed pages.
- **Google Search Direct Query:** You can search Google directly using the `site:` operator:
  ```
  site:mooziac.threeten.site
  ```
  or
  ```
  site:github.com/shirkeharsh/mooziac
  ```

---

## 7. Important Search Engine Facts & Timelines

- **Indexing is not instantaneous:** Crawling and initial indexing typically take anywhere from a few hours to several days depending on Googlebot's crawl schedules.
- **Rankings build over time:** Search ranking improves as search engines detect backlinks, domain age, page engagement, and authoritative mentions across GitHub, tech forums, and blogs.
- **GitHub Indexing:** Google indexes GitHub repositories automatically. Having a strong descriptive README, relevant topics, clear headings, and clean metadata helps Google associate the repository with queries like `Mooziac macOS music player`.

---

## 8. SEO Checklist Summary

| Item | Location / Tool | Status |
| :--- | :--- | :--- |
| **Landing Page** | `docs/index.html` | ✅ Created with semantic HTML5 |
| **Meta Description & Title** | `docs/index.html` | ✅ Added with target branding |
| **Open Graph & Twitter Cards** | `docs/index.html` | ✅ Configured with 1200x630 OG image |
| **JSON-LD Structured Data** | `docs/index.html` | ✅ SoftwareApplication + WebSite schemas |
| **XML Sitemap** | `docs/sitemap.xml` | ✅ Valid XML sitemap ready |
| **Robots Exclusion Standard** | `docs/robots.txt` | ✅ Crawling enabled + sitemap referenced |
| **GitHub Pages Custom Domain** | `docs/CNAME` | ✅ Configured for `mooziac.threeten.site` |
| **Repository README** | `README.md` | ✅ Optimized headings & keywords |
| **Search Console Setup** | Google Search Console | ⏳ Complete manually following steps above |
