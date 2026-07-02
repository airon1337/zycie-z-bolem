/**
 * GitHub API helper
 * Fetches files from and pushes files to GitHub repos.
 */

export interface GitHubFile {
  content: string;
  sha: string;
}

/**
 * Fetch a file from a GitHub repository
 */
export async function fetchFile(
  repo: string,
  path: string,
  token: string,
  branch = "main"
): Promise<GitHubFile> {
  const url = `https://api.github.com/repos/${repo}/contents/${path}?ref=${branch}`;
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github.v3+json",
      "User-Agent": "translation-worker",
    },
  });

  if (!response.ok) {
    throw new Error(`GitHub fetch failed (${response.status}): ${await response.text()}`);
  }

  const data = (await response.json()) as { content: string; sha: string };
  const content = atob(data.content.replace(/\n/g, ""));
  return { content, sha: data.sha };
}

/**
 * Push (create or update) a file to a GitHub repository
 */
export async function pushFile(
  repo: string,
  path: string,
  content: string,
  token: string,
  message: string,
  branch = "main",
  existingSha?: string
): Promise<void> {
  // Check if file already exists (to get SHA for update)
  let sha = existingSha;
  if (!sha) {
    try {
      const existing = await fetch(
        `https://api.github.com/repos/${repo}/contents/${path}?ref=${branch}`,
        {
          headers: {
            Authorization: `Bearer ${token}`,
            Accept: "application/vnd.github.v3+json",
            "User-Agent": "translation-worker",
          },
        }
      );
      if (existing.ok) {
        const data = (await existing.json()) as { sha: string };
        sha = data.sha;
      }
    } catch {
      // File doesn't exist — that's fine, we'll create it
    }
  }

  const body: Record<string, string> = {
    message,
    content: btoa(unescape(encodeURIComponent(content))),
    branch,
  };
  if (sha) {
    body.sha = sha;
  }

  const response = await fetch(
    `https://api.github.com/repos/${repo}/contents/${path}`,
    {
      method: "PUT",
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: "application/vnd.github.v3+json",
        "User-Agent": "translation-worker",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    }
  );

  if (!response.ok) {
    throw new Error(`GitHub push failed (${response.status}): ${await response.text()}`);
  }
}
