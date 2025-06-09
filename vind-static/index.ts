import { match } from 'ts-pattern'

function Url(url: string) {
  try {
    return new URL(url)
  } catch (error) {
    return null
  }
}

const chromeUrl = `https://chrome.google.com/webstore/detail/vind/ocohbenbjomofbknmcmaedadcmonedee`
const firefoxUrl = `https://addons.mozilla.org/en-US/firefox/addon/vind/`
const repoUrl = `https://github.com/joacoesteban/vind`
const discordUrl = `https://discord.gg/EGTEFnTk`

export default {
  async fetch(
    request: Request,
    env: Env,
    _ctx: ExecutionContext,
  ): Promise<Response> {
    return routeRequest(request, env)
  },
}

function routeRequest(request: Request, env: Env) {
  const url = Url(request.url)

  if (!url) {
    return new Response('Invalid URL', { status: 400 })
  }

  const pathname = url.pathname

  console.log(`Request for ${pathname}`)
  return match<string, Promise<Response>>(pathname)
    .with('/chrome', async () => Response.redirect(chromeUrl, 301))
    .with('/firefox', async () => Response.redirect(firefoxUrl, 301))
    .with('/repo', toRepo)
    .with('/github', toRepo)
    .with('/discord', toDiscord)
    .otherwise(() => env.ASSETS.fetch(request))
}

const toRepo = async () => Response.redirect(repoUrl, 301)
const toDiscord = async () => Response.redirect(discordUrl, 301)
