'use strict';

const fs = require('fs');
const path = require('path');
const readline = require('readline');

// --- Path to templates directory ---
const TEMPLATE_DIR = path.resolve(__dirname, '..', '..', '..', 'templates');

// --- Default values ---
const DEFAULTS = {
  port: '8080',
  internalPort: '8080',
  image: 'nginx',
  version: 'latest',
  description: 'A homelab service managed by Hawk methodology',
};

// --- Colors (ANSI, disabled if not TTY) ---
const isTTY = process.stdout.isTTY;
const C = {
  green: isTTY ? '\x1b[0;32m' : '',
  blue: isTTY ? '\x1b[0;34m' : '',
  yellow: isTTY ? '\x1b[1;33m' : '',
  red: isTTY ? '\x1b[0;31m' : '',
  nc: isTTY ? '\x1b[0m' : '',
};

// --- Prompt user with default ---
function prompt(rl, question, defaultVal) {
  return new Promise((resolve) => {
    rl.question(`${question} [${defaultVal}]: `, (answer) => {
      resolve(answer.trim() || defaultVal);
    });
  });
}

// --- Interactive mode ---
async function interactiveMode(argv) {
  console.log('');
  console.log(`${C.blue}╔══════════════════════════════════════════╗${C.nc}`);
  console.log(`${C.blue}║   hawk-homelab — Project Initializer     ║${C.nc}`);
  console.log(`${C.blue}╚══════════════════════════════════════════╝${C.nc}`);
  console.log('');

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  try {
    argv.projectName = await prompt(rl, 'Project name', 'my-project');
    argv.port = await prompt(rl, 'External port', argv.port || DEFAULTS.port);
    argv.internalPort = await prompt(rl, 'Internal port', argv.internalPort || DEFAULTS.internalPort);
    argv.image = await prompt(rl, 'Docker image', argv.image || DEFAULTS.image);
    argv.version = await prompt(rl, 'Image version', argv.version || DEFAULTS.version);
    argv.description = await prompt(rl, 'Project description', argv.description || DEFAULTS.description);
  } finally {
    rl.close();
  }

  console.log('');
  return argv;
}

// --- Parse CLI arguments ---
function parseArgs(args) {
  const argv = {
    projectName: '',
    port: DEFAULTS.port,
    internalPort: DEFAULTS.internalPort,
    image: DEFAULTS.image,
    version: DEFAULTS.version,
    description: DEFAULTS.description,
  };

  let i = 0;
  while (i < args.length) {
    const arg = args[i];
    switch (arg) {
      case '--port':
        argv.port = args[++i];
        break;
      case '--internal-port':
        argv.internalPort = args[++i];
        break;
      case '--image':
        argv.image = args[++i];
        break;
      case '--version':
        argv.version = args[++i];
        break;
      case '--description':
        argv.description = args[++i];
        break;
      default:
        if (arg.startsWith('-')) {
          console.error(`${C.red}Unknown option: ${arg}${C.nc}`);
          process.exit(1);
        }
        if (!argv.projectName) {
          argv.projectName = arg;
        } else {
          console.error(`${C.red}Unexpected argument: ${arg}${C.nc}`);
          process.exit(1);
        }
    }
    i++;
  }

  return argv;
}

// --- Recursively copy directory ---
function copyDirSync(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    if (entry.isDirectory()) {
      copyDirSync(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

// --- Replace placeholders in a file ---
function replacePlaceholders(filePath, vars) {
  let content = fs.readFileSync(filePath, 'utf8');

  const today = new Date().toISOString().slice(0, 10);

  content = content.replace(/\{\{PROJECT_NAME\}\}/g, vars.projectName);
  content = content.replace(/\{\{PORT\}\}/g, vars.port);
  content = content.replace(/\{\{INTERNAL_PORT\}\}/g, vars.internalPort);
  content = content.replace(/\{\{IMAGE\}\}/g, vars.image);
  content = content.replace(/\{\{VERSION\}\}/g, vars.version);
  content = content.replace(/\{\{PROJECT_DESCRIPTION\}\}/g, vars.description);
  content = content.replace(/\{\{SERVICE_DESCRIPTION\}\}/g, vars.description);
  content = content.replace(/\{\{DATE\}\}/g, today);

  fs.writeFileSync(filePath, content, 'utf8');
}

// --- Recursively replace placeholders in all files ---
function replaceAll(dir, vars) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      replaceAll(fullPath, vars);
    } else {
      replacePlaceholders(fullPath, vars);
    }
  }
}

// --- Make .sh files executable ---
function makeExecutable(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      makeExecutable(fullPath);
    } else if (entry.name.endsWith('.sh')) {
      fs.chmodSync(fullPath, 0o755);
    }
  }
}

// --- Print directory tree ---
function printTree(dir, prefix) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const count = entries.length;

  entries.forEach((entry, i) => {
    const isLast = i === count - 1;
    const connector = isLast ? '└── ' : '├── ';
    const nextPrefix = prefix + (isLast ? '    ' : '│   ');

    if (entry.isDirectory()) {
      console.log(`${prefix}${connector}${entry.name}/`);
      printTree(path.join(dir, entry.name), nextPrefix);
    } else {
      console.log(`${prefix}${connector}${entry.name}`);
    }
  });
}

// --- Main init function ---
async function init(args) {
  let argv = parseArgs(args);

  // If no project name, enter interactive mode
  if (!argv.projectName) {
    argv = await interactiveMode(argv);
  }

  // Validate
  if (!argv.projectName) {
    console.error(`${C.red}Error: Project name is required.${C.nc}`);
    process.exit(1);
  }

  const targetDir = path.resolve(process.cwd(), argv.projectName);

  if (fs.existsSync(targetDir)) {
    console.error(`${C.red}Error: Directory '${argv.projectName}' already exists.${C.nc}`);
    process.exit(1);
  }

  if (!fs.existsSync(TEMPLATE_DIR)) {
    console.error(`${C.red}Error: Templates directory not found at ${TEMPLATE_DIR}${C.nc}`);
    process.exit(1);
  }

  console.log('');
  console.log(`${C.blue}Creating project: ${argv.projectName}${C.nc}`);
  console.log(`  Image:  ${argv.image}:${argv.version}`);
  console.log(`  Port:   ${argv.port} → ${argv.internalPort}`);
  console.log('');

  // Step 1: Copy templates
  copyDirSync(TEMPLATE_DIR, targetDir);

  // Step 2: Replace placeholders
  replaceAll(targetDir, argv);

  // Step 3: Make scripts executable
  makeExecutable(targetDir);

  // Step 4: Print success
  console.log(`${C.green}✅ Project '${argv.projectName}' created successfully!${C.nc}`);
  console.log('');
  console.log('Directory structure:');
  console.log(`${argv.projectName}/`);
  printTree(targetDir, '');

  console.log('');
  console.log(`${C.yellow}Next steps:${C.nc}`);
  console.log(`  cd ${argv.projectName}`);
  console.log('  # Edit docker-compose.yml and other configs as needed');
  console.log('  bash deploy.sh');
  console.log('');
}

module.exports = { init };
