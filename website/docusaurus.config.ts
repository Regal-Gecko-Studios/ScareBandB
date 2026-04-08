import { themes as prismThemes } from 'prism-react-renderer';
import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import { type } from '@generated/site-storage';

const config: Config = {
  title: 'ScareBandB Docs',
  tagline: 'Repo tooling, Unreal workflow, and living project documentation.',
  favicon: 'img/favicon.ico',

  future: {
    v4: true,
  },

  url: 'https://scarebandb.example.com',
  baseUrl: '/',
  organizationName: 'Rim28',
  projectName: 'ScareBandB',

  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          path: '../Docs',
          routeBasePath: 'docs',
          sidebarPath: './sidebars.ts',
          exclude: ['**/Snapshots/**', '**/Templates/**'],
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  themeConfig: {
    image: 'img/docusaurus-social-card.jpg',
    announcementBar: {
      id: 'lean-docs',
      content: 'Living repo docs. Build gameplay first. Use process only where it removes friction.',
      backgroundColor: '#7d101f',
      textColor: '#fff5f7',
      isCloseable: true,
    },
    colorMode: {
      defaultMode: 'dark',
      respectPrefersColorScheme: false,
    },
    navbar: {
      title: 'ScareBandB',
      logo: {
        alt: 'ScareBandB Docs',
        src: 'img/logo.svg',
      },
      items: [
        {
          to: '/docs/',
          position: 'left',
          label: 'Handbook',
        },
        {
          type: 'doc',
          docId: 'GameDesign/README',
          position: 'left',
          label: 'Game Design',
        },
        {
          type: 'doc',
          docId: 'Pipeline/README',
          position: 'left',
          label: 'Workflow',
        },
        {
          type: 'doc',
          docId: 'Setup',
          position: 'left',
          label: 'Setup',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Build',
          items: [
            {
              label: 'Overview',
              to: '/docs/',
            },
            {
              label: 'Setup',
              to: '/docs/setup',
            },
            {
              label: 'Workflow',
              to: '/docs/workflow',
            },
          ],
        },
        {
          title: 'Design',
          items: [
            {
              label: 'Game Design',
              to: '/docs/game-design/overview',
            },
            {
              label: 'Project Structure',
              to: '/docs/project-structure',
            },
          ],
        },
        {
          title: 'Reference',
          items: [
            {
              label: 'Testing',
              to: '/docs/testing',
            },
            {
              label: 'Coding Standards',
              to: '/docs/coding-standards',
            },
            {
              label: 'Docs Site',
              to: '/docs/docs-site',
            },
            {
              label: 'Codex Context',
              to: '/docs/codex-context',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} ScareBandB. Built with Docusaurus.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
