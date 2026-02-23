# FlashFix — Deploy from GitHub to Vercel

## Files
```
index.html   ← the entire app
vercel.json  ← Vercel static deployment config
.gitignore
```

## Steps

### 1. Push to GitHub
u o```bash
git init
git add .
git commit -m "initial"
git branch -M main
git remote add origin https://github.com/dustin651/FLASHFIXTURNOVER.COM.git
git push -rigin main
```

### 2. Deploy on Vercel
1. Go to [vercel.com](https://vercel.com) → **Add New Project**
2. Import your GitHub repo
3. Framework Preset → **Other**
4. Root Directory → leave as `/`
5. Click **Deploy**

### 3. After Deploy — Supabase Auth
In Supabase → **Authentication → URL Configuration**:
- Site URL: `https://your-project.vercel.app`
- Redirect URLs: `https://your-project.vercel.app`

### 4. Run the SQL Schema
In Supabase → **SQL Editor**, paste and run the schema
from the HTML comments at the bottom of `index.html`.
