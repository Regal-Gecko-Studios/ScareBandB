import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

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
    colorMode: {
      respectPrefersColorScheme: true,
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
          label: 'Docs',
        },
        {
          type: 'doc',
          docId: 'Setup',
          position: 'left',
          label: 'Setup',
        },
        {
          type: 'doc',
          docId: 'Testing',
          position: 'left',
          label: 'Testing',
        },
      ],
    },
    footer: {
      style: 'dark',
      links: [
        {
          title: 'Project',
          items: [
            {
              label: 'Overview',
              to: '/docs/',
            },
            {
              label: 'Workflow',
              to: '/docs/workflow',
            },
          ],
        },
        {
          title: 'Tooling',
          items: [
            {
              label: 'Setup',
              to: '/docs/setup',
            },
            {
              label: 'Testing',
              to: '/docs/testing',
            },
          ],
        },
        {
          title: 'Docs Site',
          items: [
            {
              label: 'Docusaurus Setup',
              to: '/docs/docs-site/setup',
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
