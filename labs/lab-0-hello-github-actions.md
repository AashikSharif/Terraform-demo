# Lab 0 — Hello GitHub Actions

**Level:** Easy · **Time:** ~15 min · **Azure needed:** No

A warm-up before the Terraform pipeline labs. You'll create a workflow that runs
automatically and prints messages **when you push a commit** and **when a pull request is
merged** — so you can *see* how GitHub Actions triggers work before wiring it to Azure.

## What you'll practice
- What a workflow, trigger, job, and step are.
- The difference between a **push** event and a **pull_request** event.
- How to read a run in the **Actions** tab.

## Prerequisites
- A GitHub repository you own (an empty one is fine).
- Git installed and the repo cloned locally.

---

## Steps

### 1. Create the workflow file
In your repo, create the folder and file `.github/workflows/hello.yml` with this content:

```yaml
name: Hello Actions

# WHEN should this run? (triggers)
on:
  push:                     # any commit pushed to any branch
  pull_request:             # when a PR is opened/updated...
    types: [closed]         # ...here we only care about it closing
  workflow_dispatch:        # a manual "Run workflow" button

jobs:
  say-hello:
    runs-on: ubuntu-latest  # a fresh Linux machine, created just for this run
    steps:
      - name: Print a greeting
        run: echo "Hello from GitHub Actions! 👋"

      - name: Show what triggered this run
        run: |
          echo "Event   : ${{ github.event_name }}"
          echo "Who     : ${{ github.actor }}"
          echo "Branch  : ${{ github.ref_name }}"
          echo "Commit  : ${{ github.sha }}"
          echo "Message : ${{ github.event.head_commit.message }}"

  # This second job runs ONLY when a pull request was actually merged.
  on-merge:
    if: github.event_name == 'pull_request' && github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    steps:
      - name: Announce the merge
        run: |
          echo "🎉 PR #${{ github.event.pull_request.number }} was merged"
          echo "into branch '${{ github.event.pull_request.base.ref }}'"
```

### 2. Commit and push — this is your "commit observed" trigger
```bash
git add .github/workflows/hello.yml
git commit -m "Add hello world workflow"
git push origin main
```

### 3. Watch it run
Open your repo on GitHub → **Actions** tab. You'll see a run called **Hello Actions**.
Click it → click the **say-hello** job → expand the steps. You should see your greeting and
the details of the commit that triggered it.

### 4. Trigger it again with another commit
Make any small change (edit the README), commit, and push. A new run appears — proving the
workflow fires on **every push**.

### 5. See the "merge observed" trigger
1. Create a branch, make a change, and open a Pull Request:
   ```bash
   git checkout -b test-change
   echo "hello" >> notes.txt
   git add notes.txt && git commit -m "Test change"
   git push origin test-change
   ```
   Then open a PR on GitHub (base `main`, compare `test-change`).
2. Click **Merge pull request** → **Confirm merge**.
3. Go back to **Actions**. You'll see a run where **both** jobs ran: `say-hello` **and**
   `on-merge` (which only appears because the PR was truly merged). Merging also pushed a
   commit to `main`, so you'll see a second push-triggered run too.

### 6. Try the manual button
On the **Actions** tab, pick **Hello Actions** on the left → **Run workflow** → **Run**.
That's the `workflow_dispatch` trigger — handy for testing without committing.

---

## Done when
- Pushing a commit produces a run that prints your greeting and commit info.
- Merging a PR produces a run where the **on-merge** job also runs.

## What you learned
- **`on:`** decides *when* a workflow runs. `push` = a commit lands; `pull_request` with
  `types: [closed]` + the `merged == true` check = a PR was merged; `workflow_dispatch` = a
  manual button.
- A **job** runs on a fresh runner; **steps** run in order inside it.
- **`${{ github.* }}`** context variables tell you who/what triggered the run.
- This is the exact same machinery the Terraform labs use — there, the steps run
  `terraform plan`/`apply` instead of `echo`.

## Cleanup
Nothing to clean up (no cloud resources). You can delete `notes.txt` and the test branch if
you like.
