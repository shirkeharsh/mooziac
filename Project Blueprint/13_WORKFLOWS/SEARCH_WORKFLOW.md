# Search Workflow

How searching for music works in Mooziac.

## Search entry points

| Entry | Where | Behavior |
| :--- | :--- | :--- |
| Type in YTM search box | webview | native YTM search UI |
| `mooziac://` URL scheme | external | opens webview to URL |
| History item (offline-only) | HistoryManager | **search fallback** below |
| Playlist online item play | PlaylistManager | YTM watch URL / radio |

## History playback fallback search

```
User plays a history entry with no local file
  ├─ isNetworkAvailable?
  │     ├─ yes → build URL https://music.youtube.com/search?q="<title> <artist>"
  │     └─ no  → switch engine to online mode; same URL (queued for when network returns)
  └─ load URL in webview (main thread) → YTM renders results
```

## Playlist online-item play

```
PlaylistLibraryView.playItem(refType == online / refId videoId)
  ├─ JS play? → else
  ├─ load https://music.youtube.com/watch?v=<vid>
  │     └─ if JS returns false → load https://music.youtube.com/watch?v=<vid>&list=RDAMVM<vid> (radio)
  └─ fallback: search URL
```

## Search within offline library

- Offline views filter `LocalLibraryManager.allTracks` in-memory (title/artist/album substring match). No separate search endpoint.

## No dedicated app-side search engine

- Mooziac does not implement its own search index; all online search is delegated to YouTube Music's page.
- Lyrics "search" is provider-side (LRCLib query), unrelated to track search.

## Related

- `13_WORKFLOWS/PLAYBACK_WORKFLOW.md`, `09_NETWORK/API_CATALOG.md`.