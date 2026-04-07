import type {SidebarsConfig} from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  docsSidebar: [
    'README',
    'Setup',
    {
      type: 'category',
      label: 'Codex Context',
      items: [
        'Codex/README',
        'Codex/Project-Context',
        'Codex/How-It-Fits-Together',
        'Codex/Shared-vs-Private',
      ],
    },
    'Testing',
    {
      type: 'category',
      label: 'Workflow',
      items: ['Pipeline/README'],
    },
    {
      type: 'category',
      label: 'Project Structure',
      items: [
        'ProjectStructure/Target-Structure',
        'ProjectStructure/UE-Editor-Migration',
      ],
    },
    {
      type: 'category',
      label: 'Docs Site',
      items: ['DocsSite/Docusaurus-Setup', 'DocsSite/Authoring'],
    },
    {
      type: 'category',
      label: 'Coding Standards',
      items: [
        'CodingStandards/README',
        'CodingStandards/Generated/UnrealCppStandard-Digest',
      ],
    },
  ],
};

export default sidebars;
