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

const wikiSidebar = [
  {
    text: 'Вики OmniScope',
    items: [
      { text: '← Главная', link: '/' },
      { text: 'README репозитория (sync)', link: '/wiki/repository-readme' },
      { text: 'Обзор и потоки данных', link: '/wiki/overview' },
      { text: 'Архитектурный фундамент', link: '/wiki/architecture-foundation' },
      { text: 'Авто-регистрация ресурсов', link: '/wiki/auto-registration' },
      { text: 'Full stack (IaaS / PaaS / K8s / Functions)', link: '/wiki/full-stack' },
      { text: 'APM и распределённые трассы', link: '/wiki/apm-tracing' },
      { text: 'Grafana multi-datasource', link: '/wiki/grafana' },
      { text: 'Алертинг и ITSM', link: '/wiki/alerting-itsm' },
      { text: 'IaC (Terraform)', link: '/wiki/iac-terraform' },
      { text: 'Воркшоп', link: '/wiki/workshop' },
      { text: 'Примеры на AKS', link: '/wiki/hands-on-examples' },
      { text: 'Cheat-sheet операторов', link: '/wiki/appendix-operators' },
    ],
  },
]

export default defineConfig({
  base,
  title: 'OmniScope Wiki',
  description: 'Эталонная Observability-платформа для PZU в Azure',
  lang: 'ru-RU',
  appearance: 'force-dark',
  themeConfig: {
    nav: [
      { text: 'Главная', link: '/' },
      { text: 'Вики', link: '/wiki/overview', activeMatch: '/wiki/' },
    ],
    sidebar: {
      '/wiki/': wikiSidebar,
      '/': [
        {
          text: 'Навигация',
          items: [
            { text: 'OmniScope Wiki (главная)', link: '/' },
            { text: 'Все статьи вики', link: '/wiki/overview' },
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
