import { themes as prismThemes } from 'prism-react-renderer';
import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'ScareBandB Docs',
  tagline: 'Repo tooling, Unreal workflow, and living project documentation.',
  favicon: 'img/logo.svg',

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
          exclude: ['**/Current/**', '**/Templates/**'],
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
          label: 'Overview',
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
          title: 'Start',
          items: [
            {
              label: 'Overview',
              to: '/docs/',
            },
            {
              label: 'Game Design',
              to: '/docs/game-design/overview',
            },
            {
              label: 'Setup',
              to: '/docs/setup',
            },
          ],
        },
        {
          title: 'Build',
          items: [
            {
              label: 'Workflow',
              to: '/docs/workflow',
            },
            {
              label: 'Project Structure',
              to: '/docs/project-structure',
            },
            {
              label: 'Testing',
              to: '/docs/testing',
            },
          ],
        },
        {
          title: 'Reference',
          items: [
            {
              label: 'Coding Standards',
              to: '/docs/coding-standards',
            },
          ],
        },
      ],
      copyright: `ScareBandB documentation for the current project state. ${new Date().getFullYear()}.`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
