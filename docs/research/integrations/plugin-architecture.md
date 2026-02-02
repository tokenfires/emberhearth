# Plugin Architecture Research

**Status:** Complete
**Priority:** Medium (v2+)
**Last Updated:** February 2, 2026

---

## Overview

A plugin architecture allows third-party developers and power users to extend EmberHearth's capabilities. This is key to building an ecosystem and supporting apps that EmberHearth doesn't natively integrate with.

## Goals

| Goal | Description |
|------|-------------|
| **Extensibility** | Support apps EmberHearth doesn't know about |
| **Security** | Plugins can't compromise user data |
| **Accessibility** | Easy for developers of all skill levels |
| **Discoverability** | Users can find and install plugins easily |
| **Composability** | Plugins can leverage EmberHearth's built-in integrations |

---

## Recommended Approach: TypeScript + MCP-Style Architecture

After evaluating options, we recommend a **TypeScript-based plugin system** with an **MCP-like interface** rather than native XPC. This dramatically lowers the barrier to entry while maintaining security through sandboxing.

### Why TypeScript Over XPC?

| Factor | XPC (Swift) | TypeScript |
|--------|-------------|------------|
| Developer pool | Small (macOS devs only) | Massive (millions) |
| Learning curve | Steep | Gentle |
| Tooling | Xcode required | VS Code, any editor |
| Sandboxing | Complex to implement | JavaScriptCore built-in |
| Distribution | Code signing complexity | Simple bundles |
| Cross-platform potential | None | Future iOS, web |

### Why MCP-Style?

The Model Context Protocol (MCP) pattern provides:
- **Declarative tool definitions** — LLM understands available actions
- **Typed parameters** — Clear contracts, fewer errors
- **Discoverability** — Plugins self-describe their capabilities
- **Composability** — Tools can be combined naturally

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         EmberHearth Core                             │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                         LLM                                 │    │
│  │  Sees all plugin tools as available actions:               │    │
│  │  - todoist.list_tasks(project?, filter?)                   │    │
│  │  - todoist.add_task(content, due?, project?)               │    │
│  │  - notion.search_pages(query)                              │    │
│  │  - slack.send_message(channel, text)                       │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│                              ▼                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                    Plugin Manager                           │    │
│  │  - Loads plugin manifests                                  │    │
│  │  - Registers tools with LLM                                │    │
│  │  - Routes tool calls to plugins                            │    │
│  │  - Enforces permissions                                    │    │
│  │  - Processes plugin responses + suggestions                │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │              Plugin Runtime (Sandboxed)                     │    │
│  │                                                             │    │
│  │  JavaScriptCore Engine                                     │    │
│  │  - No filesystem access                                    │    │
│  │  - No arbitrary network (declared domains only)            │    │
│  │  - All system access via EmberHearthAPI                   │    │
│  │  - Execution timeouts + memory limits                     │    │
│  └────────────────────────────────────────────────────────────┘    │
│                              │                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │              EmberHearth API (Exposed to Plugins)          │    │
│  │                                                             │    │
│  │  api.calendar    → EventKit wrapper                        │    │
│  │  api.contacts    → CNContactStore wrapper                  │    │
│  │  api.mail        → Mail.app automation                     │    │
│  │  api.notes       → Notes.app automation                    │    │
│  │  api.weather     → WeatherKit wrapper                      │    │
│  │  api.homekit     → HomeKit wrapper                         │    │
│  │  api.secrets     → Keychain (plugin-scoped)               │    │
│  │  api.fetch       → Network (domain-restricted)            │    │
│  │  api.storage     → Plugin-local persistence               │    │
│  └────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Plugin Structure

### Directory Layout

```
my-plugin/
├── manifest.json          # Plugin metadata + tool definitions
├── plugin.ts              # Main plugin code
├── package.json           # Dependencies (optional)
└── README.md              # Documentation
```

### Plugin Manifest (manifest.json)

```json
{
  "name": "Todoist Integration",
  "identifier": "com.example.todoist",
  "version": "1.0.0",
  "description": "Manage your Todoist tasks through EmberHearth",
  "author": {
    "name": "Jane Developer",
    "email": "jane@example.com",
    "website": "https://example.com"
  },
  "minEmberHearthVersion": "2.0.0",

  "permissions": {
    "network": ["api.todoist.com"],
    "secrets": true,
    "emberhearthApi": ["calendar"]
  },

  "tools": [
    {
      "name": "list_tasks",
      "description": "Get tasks from Todoist, optionally filtered by project or label",
      "parameters": {
        "type": "object",
        "properties": {
          "project": {
            "type": "string",
            "description": "Filter by project name"
          },
          "filter": {
            "type": "string",
            "description": "Todoist filter query (e.g., 'today', 'overdue')"
          }
        }
      },
      "returns": {
        "type": "array",
        "items": {
          "type": "object",
          "properties": {
            "id": { "type": "string" },
            "content": { "type": "string" },
            "due": { "type": "string" },
            "priority": { "type": "number" }
          }
        }
      }
    },
    {
      "name": "add_task",
      "description": "Create a new task in Todoist",
      "parameters": {
        "type": "object",
        "properties": {
          "content": {
            "type": "string",
            "description": "Task content/title"
          },
          "due": {
            "type": "string",
            "description": "Due date (natural language: 'tomorrow', 'next Monday')"
          },
          "project": {
            "type": "string",
            "description": "Project to add task to"
          },
          "priority": {
            "type": "number",
            "description": "Priority 1-4 (4 is highest)"
          }
        },
        "required": ["content"]
      }
    },
    {
      "name": "sync_to_calendar",
      "description": "Sync Todoist deadlines to Apple Calendar",
      "parameters": {
        "type": "object",
        "properties": {
          "project": {
            "type": "string",
            "description": "Only sync tasks from this project"
          }
        }
      }
    }
  ],

  "settings": [
    {
      "key": "api_token",
      "type": "secret",
      "label": "Todoist API Token",
      "description": "Get this from Todoist Settings → Integrations → API token",
      "required": true
    },
    {
      "key": "default_project",
      "type": "string",
      "label": "Default Project",
      "description": "Project to use when none specified",
      "required": false
    }
  ]
}
```

### Plugin Implementation (plugin.ts)

```typescript
import { EmberHearthAPI, PluginResponse, Tool } from '@emberhearth/plugin-sdk';

// ============================================================================
// Tool: list_tasks
// ============================================================================

export async function list_tasks(
  api: EmberHearthAPI,
  params: { project?: string; filter?: string }
): Promise<PluginResponse> {

  const token = await api.secrets.get('api_token');
  if (!token) {
    return {
      error: "Todoist API token not configured. Please set it in plugin settings."
    };
  }

  // Build API URL
  let url = 'https://api.todoist.com/rest/v2/tasks';
  if (params.filter) {
    url += `?filter=${encodeURIComponent(params.filter)}`;
  }

  // Fetch tasks (network restricted to declared domains)
  const response = await api.fetch(url, {
    headers: { 'Authorization': `Bearer ${token}` }
  });

  if (!response.ok) {
    return { error: `Todoist API error: ${response.status}` };
  }

  const tasks = await response.json();

  // Filter by project if specified
  const filtered = params.project
    ? tasks.filter((t: any) => t.project_id === params.project)
    : tasks;

  // Check for overdue tasks
  const overdue = filtered.filter((t: any) => {
    if (!t.due?.date) return false;
    return new Date(t.due.date) < new Date();
  });

  return {
    // Data returned to user
    result: filtered,

    // Formatted message for display
    message: formatTaskList(filtered),

    // Suggestions for the LLM (not commands, just hints)
    suggestions: overdue.length > 0 ? [
      {
        hint: `There are ${overdue.length} overdue tasks. Consider asking if the user wants to reschedule them or mark them complete.`,
        relevance: 'high'
      }
    ] : undefined,

    // Request additional context if useful
    contextRequest: filtered.some((t: any) => t.due?.date) ? {
      type: 'calendar',
      query: 'events this week',
      reason: 'To identify potential conflicts with task deadlines'
    } : undefined
  };
}

// ============================================================================
// Tool: add_task
// ============================================================================

export async function add_task(
  api: EmberHearthAPI,
  params: { content: string; due?: string; project?: string; priority?: number }
): Promise<PluginResponse> {

  const token = await api.secrets.get('api_token');

  const response = await api.fetch('https://api.todoist.com/rest/v2/tasks', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      content: params.content,
      due_string: params.due,
      project_id: params.project,
      priority: params.priority
    })
  });

  if (!response.ok) {
    return { error: `Failed to create task: ${response.status}` };
  }

  const task = await response.json();

  return {
    result: task,
    message: `✓ Created task: "${params.content}"${params.due ? ` (due: ${params.due})` : ''}`,

    // Suggest follow-up if task has a due date
    suggestions: params.due ? [
      {
        hint: `Task has a deadline. You could offer to add it to the user's calendar as well.`,
        relevance: 'medium'
      }
    ] : undefined
  };
}

// ============================================================================
// Tool: sync_to_calendar (uses EmberHearth's Calendar API)
// ============================================================================

export async function sync_to_calendar(
  api: EmberHearthAPI,
  params: { project?: string }
): Promise<PluginResponse> {

  // Get tasks with due dates
  const tasksResponse = await list_tasks(api, {
    project: params.project,
    filter: 'due before: +7 days'
  });

  if (tasksResponse.error) {
    return tasksResponse;
  }

  const tasks = tasksResponse.result as any[];
  const tasksWithDue = tasks.filter(t => t.due?.date);

  if (tasksWithDue.length === 0) {
    return {
      message: "No tasks with due dates found to sync."
    };
  }

  // Use EmberHearth's Calendar API (plugin has permission)
  let synced = 0;
  for (const task of tasksWithDue) {
    try {
      await api.calendar.createEvent({
        title: `[Todoist] ${task.content}`,
        startDate: new Date(task.due.date),
        endDate: new Date(task.due.date),
        isAllDay: !task.due.datetime,
        notes: `Synced from Todoist\nTask ID: ${task.id}`,
        calendar: 'Tasks'  // Or let user configure
      });
      synced++;
    } catch (e) {
      // Skip if event already exists or calendar unavailable
    }
  }

  return {
    message: `✓ Synced ${synced} task deadlines to Calendar`,
    result: { syncedCount: synced, totalTasks: tasksWithDue.length }
  };
}

// ============================================================================
// Helpers
// ============================================================================

function formatTaskList(tasks: any[]): string {
  if (tasks.length === 0) {
    return "No tasks found.";
  }

  return tasks.map((t, i) => {
    const due = t.due?.date ? ` (due: ${t.due.date})` : '';
    const priority = t.priority > 1 ? ` [P${5 - t.priority}]` : '';
    return `${i + 1}. ${t.content}${due}${priority}`;
  }).join('\n');
}
```

---

## EmberHearth API (Exposed to Plugins)

Plugins access macOS capabilities through EmberHearth's vetted APIs, not directly.

```typescript
interface EmberHearthAPI {

  // =========================================================================
  // Core macOS Integrations (require permission)
  // =========================================================================

  calendar: {
    getEvents(options: { start: Date; end: Date; calendar?: string }): Promise<CalendarEvent[]>;
    createEvent(event: NewCalendarEvent): Promise<CalendarEvent>;
    updateEvent(id: string, updates: Partial<CalendarEvent>): Promise<CalendarEvent>;
    deleteEvent(id: string): Promise<void>;
    getCalendars(): Promise<Calendar[]>;
  };

  reminders: {
    getReminders(options?: { list?: string; completed?: boolean }): Promise<Reminder[]>;
    createReminder(reminder: NewReminder): Promise<Reminder>;
    completeReminder(id: string): Promise<void>;
    getLists(): Promise<ReminderList[]>;
  };

  contacts: {
    search(query: string): Promise<Contact[]>;
    getContact(id: string): Promise<Contact>;
    getGroups(): Promise<ContactGroup[]>;
  };

  mail: {
    getMessages(options: { mailbox?: string; limit?: number; unreadOnly?: boolean }): Promise<MailMessage[]>;
    sendMessage(message: NewMailMessage): Promise<{ success: boolean; requiresConfirmation?: boolean }>;
    moveMessage(id: string, toMailbox: string): Promise<void>;
    flagMessage(id: string, flagged: boolean): Promise<void>;
  };

  notes: {
    getNotes(options?: { folder?: string; limit?: number }): Promise<Note[]>;
    createNote(note: NewNote): Promise<Note>;
    updateNote(id: string, content: string): Promise<Note>;
    searchNotes(query: string): Promise<Note[]>;
  };

  weather: {
    getCurrent(location?: string | { lat: number; lon: number }): Promise<CurrentWeather>;
    getForecast(location?: string, days?: number): Promise<DailyForecast[]>;
    getAlerts(location?: string): Promise<WeatherAlert[]>;
  };

  homekit: {
    getDevices(): Promise<HomeKitDevice[]>;
    getDeviceState(deviceId: string): Promise<DeviceState>;
    setDeviceState(deviceId: string, state: Partial<DeviceState>): Promise<void>;
    runScene(sceneName: string): Promise<void>;
  };

  // =========================================================================
  // Plugin Utilities
  // =========================================================================

  secrets: {
    get(key: string): Promise<string | null>;
    set(key: string, value: string): Promise<void>;
    delete(key: string): Promise<void>;
  };

  storage: {
    get<T>(key: string): Promise<T | null>;
    set<T>(key: string, value: T): Promise<void>;
    delete(key: string): Promise<void>;
    list(): Promise<string[]>;
  };

  fetch(url: string, options?: FetchOptions): Promise<Response>;

  log: {
    debug(message: string, data?: any): void;
    info(message: string, data?: any): void;
    warn(message: string, data?: any): void;
    error(message: string, data?: any): void;
  };
}
```

---

## Plugin Response Format

Plugins return structured responses that include data, display formatting, and optional suggestions for the LLM.

```typescript
interface PluginResponse {
  // The actual data/result (for further processing)
  result?: any;

  // Human-readable message for display
  message?: string;

  // Error message if something went wrong
  error?: string;

  // Suggestions for the LLM (hints, not commands)
  suggestions?: PluginSuggestion[];

  // Request additional context from EmberHearth
  contextRequest?: ContextRequest;
}

interface PluginSuggestion {
  // Natural language hint for the LLM
  hint: string;

  // How relevant/important is this suggestion
  relevance: 'low' | 'medium' | 'high';

  // Optional: specific action the LLM could take
  suggestedAction?: {
    tool: string;
    parameters?: Record<string, any>;
  };
}

interface ContextRequest {
  // What type of context is needed
  type: 'calendar' | 'contacts' | 'weather' | 'notes' | 'mail';

  // Specific query
  query: string;

  // Why this context would help (shown to user for transparency)
  reason: string;
}
```

---

## LLM Integration Flow

```
User: "Check my Todoist and see if I have time for those tasks today"

┌─────────────────────────────────────────────────────────────────────┐
│ Step 1: LLM plans actions                                           │
│                                                                      │
│ Based on available tools, LLM decides to call:                      │
│ 1. todoist.list_tasks({ filter: "today | overdue" })               │
│ 2. calendar.get_events({ start: today, end: today })               │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Step 2: Plugin executes                                             │
│                                                                      │
│ Todoist plugin:                                                     │
│ - Fetches tasks from API                                            │
│ - Returns task list                                                 │
│ - Includes suggestion: "3 overdue tasks - offer to reschedule?"    │
│ - Includes contextRequest: "Get calendar to check conflicts"       │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Step 3: EmberHearth processes response                              │
│                                                                      │
│ - Honors contextRequest → fetches today's calendar                 │
│ - Passes plugin result + suggestions + calendar to LLM             │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Step 4: LLM synthesizes response                                    │
│                                                                      │
│ LLM sees:                                                           │
│ - Task list from Todoist                                            │
│ - Calendar events for today                                         │
│ - Plugin hint about overdue tasks                                   │
│                                                                      │
│ LLM responds to user:                                               │
│ "You have 5 Todoist tasks for today. Looking at your calendar,     │
│  you have meetings from 10-11 and 2-4. You should have time for    │
│  the smaller tasks in the morning and after 4pm.                   │
│                                                                      │
│  I notice 3 tasks are overdue. Want me to reschedule them?"        │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Security Model

### Sandboxed JavaScript Runtime

Plugins run in JavaScriptCore (built into macOS) with restrictions:

```swift
class PluginSandbox {
    private let jsContext: JSContext
    private let permissions: PluginPermissions

    init(manifest: PluginManifest) {
        jsContext = JSContext()
        permissions = manifest.permissions

        // Remove dangerous globals
        jsContext.evaluateScript("delete this.eval")
        jsContext.evaluateScript("delete this.Function")

        // No filesystem
        // No process spawning
        // No require() for arbitrary modules

        // Inject safe EmberHearth API
        injectEmberHearthAPI()
    }

    private func injectEmberHearthAPI() {
        // Only expose permitted APIs
        let api = JSValue(newObjectIn: jsContext)

        if permissions.secrets {
            api?.setObject(secretsAPI, forKeyedSubscript: "secrets")
        }

        if permissions.network.count > 0 {
            api?.setObject(
                createNetworkAPI(allowedDomains: permissions.network),
                forKeyedSubscript: "fetch"
            )
        }

        for integration in permissions.emberhearthApi {
            switch integration {
            case "calendar":
                api?.setObject(calendarAPI, forKeyedSubscript: "calendar")
            case "contacts":
                api?.setObject(contactsAPI, forKeyedSubscript: "contacts")
            // ... etc
            }
        }

        jsContext.setObject(api, forKeyedSubscript: "api")
    }
}
```

### Permission System

```typescript
interface PluginPermissions {
  // Network access - must declare specific domains
  network?: string[];  // e.g., ["api.todoist.com", "api.notion.com"]

  // Secret storage (plugin-scoped keychain)
  secrets?: boolean;

  // Local storage (plugin-scoped)
  storage?: boolean;

  // EmberHearth integrations - user already granted these to EmberHearth
  emberhearthApi?: Array<
    'calendar' | 'reminders' | 'contacts' | 'mail' |
    'notes' | 'weather' | 'homekit'
  >;

  // Notifications
  notifications?: boolean;
}
```

### Permission Request Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Install Plugin                                │
│                                                                  │
│  "Todoist Integration" requests permission to:                  │
│                                                                  │
│  ☑ Network access                                               │
│      → api.todoist.com                                          │
│                                                                  │
│  ☑ Store secrets                                                │
│      → To save your Todoist API token                           │
│                                                                  │
│  ☑ Access Calendar                                              │
│      → To sync task deadlines                                   │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Why these permissions?                                 │    │
│  │  This plugin needs to connect to Todoist's servers     │    │
│  │  and optionally add deadlines to your calendar.        │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│              [Cancel]                    [Allow]                 │
└─────────────────────────────────────────────────────────────────┘
```

### Security Boundaries

| What Plugins CAN Do | What Plugins CANNOT Do |
|---------------------|------------------------|
| Call declared network domains | Access arbitrary URLs |
| Use EmberHearth's APIs (if permitted) | Access macOS directly |
| Store plugin-scoped secrets | Access other plugins' data |
| Return suggestions to LLM | Execute arbitrary commands |
| Read permitted integrations | Write to integrations without permission |

### Audit Logging

All plugin actions are logged for user transparency:

```typescript
// User can review in EmberHearth settings
interface PluginAuditEntry {
  timestamp: Date;
  plugin: string;
  action: 'network' | 'secret_access' | 'api_call' | 'tool_execution';
  details: string;
  // e.g., "Network: GET api.todoist.com/rest/v2/tasks"
  // e.g., "API: calendar.createEvent('Team meeting')"
}
```

---

## Plugin Distribution

### Option 1: Plugin Directory (Recommended)

Curated directory hosted by EmberHearth:

1. Developer submits plugin (GitHub repo or upload)
2. Automated security scan:
   - Static analysis of code
   - Verify declared permissions match usage
   - Check for known vulnerabilities in dependencies
3. Manual review for quality
4. Listed in EmberHearth's plugin browser
5. Users install with one click

### Option 2: Direct Installation (Developer Mode)

For development and power users:

1. Enable "Developer Mode" in EmberHearth settings
2. Install from local directory or URL
3. Clear warning: "This plugin has not been reviewed"
4. Full audit logging enabled

### Plugin Bundle Format

```
my-plugin.emberplugin/
├── manifest.json
├── plugin.js          # Compiled TypeScript
├── plugin.js.map      # Source map (for debugging)
├── signature.json     # Developer signature
└── assets/
    └── icon.png
```

---

## Developer Experience

### SDK Package

```bash
npm install @emberhearth/plugin-sdk
```

### TypeScript Definitions

```typescript
// Full type definitions for all APIs
import {
  EmberHearthAPI,
  PluginResponse,
  CalendarEvent,
  Contact,
  // ... all types
} from '@emberhearth/plugin-sdk';
```

### Local Development

```bash
# Start development server
emberhearth-plugin dev

# Loads plugin in EmberHearth with hot reload
# Full debugging in VS Code
```

### Testing

```typescript
import { createMockAPI, TestHarness } from '@emberhearth/plugin-sdk/testing';

describe('Todoist Plugin', () => {
  it('lists tasks', async () => {
    const api = createMockAPI({
      secrets: { api_token: 'test-token' },
      fetch: mockFetch({ tasks: [...] })
    });

    const result = await list_tasks(api, { filter: 'today' });

    expect(result.result).toHaveLength(3);
    expect(result.suggestions).toContainEqual(
      expect.objectContaining({ relevance: 'high' })
    );
  });
});
```

---

## Implementation Phases

### Phase 1: Foundation (v2.0)
- [ ] JavaScriptCore sandbox implementation
- [ ] Plugin manifest parser
- [ ] EmberHearth API bridge (calendar, contacts, notes)
- [ ] Permission system
- [ ] Basic plugin loading

### Phase 2: Developer Tools (v2.1)
- [ ] Plugin SDK npm package
- [ ] CLI tools (`emberhearth-plugin` command)
- [ ] VS Code extension for debugging
- [ ] Documentation site
- [ ] Example plugins (Todoist, Notion, Slack)

### Phase 3: Distribution (v2.2)
- [ ] Plugin directory backend
- [ ] In-app plugin browser
- [ ] Automated security scanning
- [ ] Developer portal for submissions
- [ ] Update mechanism

### Phase 4: Advanced (v2.3+)
- [ ] Plugin settings UI
- [ ] Inter-plugin communication (limited, opt-in)
- [ ] Plugin analytics (opt-in, privacy-preserving)
- [ ] Enterprise deployment options

---

## Example Plugins

### Notion Integration

```typescript
export async function search_pages(api: EmberHearthAPI, params: { query: string }) {
  const token = await api.secrets.get('notion_token');
  const response = await api.fetch('https://api.notion.com/v1/search', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Notion-Version': '2022-06-28'
    },
    body: JSON.stringify({ query: params.query })
  });

  const data = await response.json();
  return {
    result: data.results,
    message: `Found ${data.results.length} pages matching "${params.query}"`
  };
}
```

### Slack Integration

```typescript
export async function send_message(
  api: EmberHearthAPI,
  params: { channel: string; text: string }
) {
  const token = await api.secrets.get('slack_token');

  // Require confirmation for sending messages
  return {
    message: `Ready to send to #${params.channel}:\n"${params.text}"`,
    requiresConfirmation: true,
    onConfirm: async () => {
      await api.fetch('https://slack.com/api/chat.postMessage', {
        method: 'POST',
        headers: { 'Authorization': `Bearer ${token}` },
        body: JSON.stringify({ channel: params.channel, text: params.text })
      });
      return { message: `✓ Message sent to #${params.channel}` };
    }
  };
}
```

### Morning Briefing (Composition Example)

```typescript
export async function morning_briefing(api: EmberHearthAPI) {
  // Leverage EmberHearth's built-in integrations
  const [calendar, weather, tasks] = await Promise.all([
    api.calendar.getEvents({
      start: new Date(),
      end: endOfDay(new Date())
    }),
    api.weather.getCurrent(),
    fetchTodoistTasks(api, { filter: 'today' })
  ]);

  return {
    result: { calendar, weather, tasks },
    message: formatBriefing(calendar, weather, tasks),
    suggestions: [
      {
        hint: "User might want this as a daily scheduled message",
        relevance: 'low'
      }
    ]
  };
}
```

---

## Resources

- [Model Context Protocol](https://modelcontextprotocol.io/) - Inspiration for tool definitions
- [VS Code Extension API](https://code.visualstudio.com/api) - Plugin UX reference
- [JavaScriptCore Framework](https://developer.apple.com/documentation/javascriptcore) - Runtime
- [Deno Security Model](https://deno.land/manual/basics/permissions) - Permission patterns

---

## Recommendation

**Feasibility: HIGH**

The TypeScript + MCP-style approach provides:

1. **Developer accessibility** — Millions of JS/TS developers can contribute
2. **Security** — Sandboxed runtime with explicit permissions
3. **Composability** — Plugins leverage EmberHearth's vetted macOS integrations
4. **LLM-native** — Tools are self-describing, LLM knows how to use them
5. **Collaboration** — Plugins can suggest actions, LLM stays in control

**Key insight:** By exposing EmberHearth's internal APIs to plugins, we get the best of both worlds — plugins are sandboxed JavaScript (safe), but can do powerful things through EmberHearth's native integrations (capable).

This should be a **v2 feature** after core functionality is stable, but the architecture should be designed with plugins in mind from v1.
