import { defineConfig } from 'vitepress'

// GitHub project pages: workflow sets VITEPRESS_BASE=/<repo>/ (leading + trailing slash).
// Local preview: omit env → base '/'.
const base = process.env.VITEPRESS_BASE || '/'

/** Public site origin (no trailing slash). CI sets DOCS_PUBLIC_URL; fallback — ваш project Pages. */
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
      { text: '← Главная', link: '/' },
      { text: 'README репозитория (sync)', link: '/guide/repository-readme' },
      { text: 'Обзор платформы', link: '/guide/overview' },
      { text: 'IaC (Bicep)', link: '/guide/iac-bicep' },
      { text: 'Runbook деплоя', link: '/guide/deployment-runbook' },
      { text: 'Observability модель', link: '/guide/observability' },
      { text: 'Алерты и маршрутизация', link: '/guide/alerts' },
      { text: 'Gateway API', link: '/guide/gateway-api' },
      { text: 'Evidence / DoD', link: '/guide/evidence' },
    ],
  },
]

export default defineConfig({
  base,
  title: 'OmniScope Docs',
  description: 'AKS + Bicep + Observability (Azure Monitor, App Insights, Grafana)',
  lang: 'ru-RU',
  appearance: 'force-dark',
  themeConfig: {
    nav: [
      { text: 'Главная', link: '/' },
      { text: 'Guide', link: '/guide/overview', activeMatch: '/guide/' },
    ],
    sidebar: {
      '/guide/': guideSidebar,
      '/': [
        {
          text: 'Навигация',
          items: [
            { text: 'OmniScope Docs (главная)', link: '/' },
            { text: 'Все статьи guide', link: '/guide/overview' },
          ],
        },
      ],
    },
    outline: {
      label: 'На этой странице',
      level: [2, 3],
    },
    search: {
      provider: 'local',
    },
    socialLinks: [{ icon: 'github', link: githubRepoUrlFromPagesOrigin(docsPublicUrl) }],
    footer: {
      message: `OmniScope Cloud · сайт документации: ${docsPublicUrl}/`,
      copyright: 'Исходники — репозиторий GitHub (иконка справа снизу)',
    },
  },
})
