#!/usr/bin/env node
/**
 * Syncs repository root README.md → doc-site/guide/repository-readme.md
 * Rewrites relative ./ links to https://github.com/<owner>/<repo>/blob/main/... so they work on GitHub Pages.
 *
 * Repo slug: GITHUB_REPOSITORY (set in GitHub Actions) or parsed from `git remote get-url origin`.
 */

import { readFileSync, writeFileSync, existsSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { execSync } from 'node:child_process'

const __dirname = dirname(fileURLToPath(import.meta.url))
const docSiteRoot = join(__dirname, '..')
const repoRoot = join(docSiteRoot, '..')
const readmePath = join(repoRoot, 'README.md')
const outPath = join(docSiteRoot, 'guide', 'repository-readme.md')

function detectGithubSlug() {
  const env = process.env.GITHUB_REPOSITORY
  if (env && /^[\w.-]+\/[\w.-]+$/.test(env)) {
    return env
  }
  try {
    const url = execSync('git remote get-url origin', {
      cwd: repoRoot,
      encoding: 'utf8',
    }).trim()
    const m =
      url.match(/github\.com[:/]([^/]+)\/([^/.]+)(?:\.git)?$/i) ||
      url.match(/github\.com\/([^/]+)\/([^/.]+)(?:\.git)?$/i)
    if (m) {
      return `${m[1]}/${m[2]}`
    }
  } catch {
    /* no git */
  }
  return null
}

function rewriteRelativeLinks(markdown, slug) {
  if (!slug) {
    console.warn(
      '[sync-readme] No GITHUB_REPOSITORY or parseable git remote — leaving ./ links unchanged (may break on GitHub Pages).',
    )
    return markdown
  }
  const base = `https://github.com/${slug}/blob/main`
  // ](./path)  or ](./path#anchor)
  return markdown.replace(/\]\(\.\/([^)]+)\)/g, `](${base}/$1)`)
}

function main() {
  if (!existsSync(readmePath)) {
    console.error('[sync-readme] Missing:', readmePath)
    process.exit(1)
  }
  const slug = detectGithubSlug()
  let body = readFileSync(readmePath, 'utf8')
  body = rewriteRelativeLinks(body, slug)

  const header = `---
title: Repository README
description: Synced from root README.md (scripts/sync-readme.mjs)
outline: deep
---

> **Auto-generated page:** content is copied from [\`README.md\`](https://github.com/${slug ?? 'YOUR_ORG/YOUR_REPO'}/blob/main/README.md) on \`npm run sync-readme\` / before VitePress build. Edit the **root** README, then rebuild docs.

`

  writeFileSync(outPath, header + body.trimEnd() + '\n', 'utf8')
  console.log('[sync-readme] Wrote', outPath, slug ? `(links → github.com/${slug})` : '')
}

main()
