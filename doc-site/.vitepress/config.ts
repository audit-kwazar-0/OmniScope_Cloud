import { defineConfig } from 'vitepress'

// GitHub project pages: workflow sets VITEPRESS_BASE=/<repo>/ (leading + trailing slash).
// Local preview: omit env → base '/'.
const base = process.env.VITEPRESS_BASE || '/'

/** Public site origin (no trailing slash). CI sets DOCS_PUBLIC_URL; fallback is project Pages URL. */
const docsPublicUrl = (process.env.DOCS_PUBLIC_URL || 'https://audit-kwazar-0.github.io/OmniScope_Cloud').replace(
  /\/$/,
  '',
)

function githubRepoUrlFromPagesOrigin(pagesUrl: string): string {
  const m = pagesUrl.match(/^https:\/\/([^.]+)\.github\.io\/([^/]+)$/)
  if (m) {
    return `https://github.com/${m[1]}/${m[2]}`
  }
  return 'https://github.com/audit-kwazar-0/OmniScope_Cloud'
}

const guideSidebar = [
  {
    text: 'OmniScope Guide',
    items: [
      { text: '← Home', link: '/' },
      { text: 'Repository README (sync)', link: '/guide/repository-readme' },
      { text: 'Platform overview', link: '/guide/overview' },
      { text: 'IaC (Bicep)', link: '/guide/iac-bicep' },
      { text: 'Deployment runbook', link: '/guide/deployment-runbook' },
      { text: 'Observability model', link: '/guide/observability' },
      { text: 'Alerts and routing', link: '/guide/alerts' },
      { text: 'Gateway API', link: '/guide/gateway-api' },
      { text: 'Evidence / DoD', link: '/guide/evidence' },
    ],
  },
]

export default defineConfig({
  base,
  title: 'OmniScope Docs',
  description: 'AKS + Bicep + Observability (Azure Monitor, App Insights, Grafana)',
  lang: 'en-US',
  appearance: 'force-dark',
  themeConfig: {
    nav: [
      { text: 'Home', link: '/' },
      { text: 'Guide', link: '/guide/overview', activeMatch: '/guide/' },
    ],
    sidebar: {
      '/guide/': guideSidebar,
      '/': [
        {
          text: 'Navigation',
          items: [
            { text: 'OmniScope Docs (home)', link: '/' },
            { text: 'All guide articles', link: '/guide/overview' },
          ],
        },
      ],
    },
    outline: {
      label: 'On this page',
      level: [2, 3],
    },
    search: {
      provider: 'local',
    },
    socialLinks: [{ icon: 'github', link: githubRepoUrlFromPagesOrigin(docsPublicUrl) }],
    footer: {
      message: `OmniScope Cloud · documentation site: ${docsPublicUrl}/`,
      copyright: 'Source: GitHub repository (icon bottom right)',
    },
  },
})
