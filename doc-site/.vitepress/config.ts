import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'OmniScope Cloud Docs',
  description: 'Эталонная Observability-платформа для PZU в Azure',
  lang: 'ru-RU',
  themeConfig: {
    nav: [
      { text: 'Главная', link: '/' },
      { text: 'Observability', link: '/#observability' },
      { text: 'Workshop', link: '/#workshop' },
    ],
    sidebar: [
      {
        text: 'Разделы',
        items: [
          { text: 'Архитектура и сбор данных', link: '/#architecture' },
          { text: 'Auto-registration ресурсов', link: '/#auto-registration' },
          { text: 'Full Stack слои', link: '/#full-stack' },
          { text: 'APM/Traces', link: '/#apm' },
          { text: 'Grafana multi-datasource', link: '/#grafana' },
          { text: 'Alerting и ITSM', link: '/#alerting-itsm' },
          { text: 'IaC Terraform', link: '/#iac-terraform' },
          { text: 'План воркшопа', link: '/#workshop' },
          { text: 'Локальные примеры OTel', link: '/#hands-on-examples' },
        ],
      },
    ],
    socialLinks: [],
  },
})

