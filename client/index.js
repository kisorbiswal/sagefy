/* eslint-disable max-lines */
const path = require('path')
const express = require('express')
const bodyParser = require('body-parser')
const cookieParser = require('cookie-parser')
const jwt = require('jsonwebtoken')
const get = require('lodash.get')
const set = require('lodash.set')
const fromPairs = require('lodash.frompairs')
const {
  convertUuid58ToUuid: toU,
  convertUuidToUuid58: to58,
} = require('uuid58')
const uuidv4 = require('uuid/v4')
const request = require('request-promise-native')
const CARD_KIND = require('./util/card-kind')
const GQL = require('./util/gql-queries')
const getGqlErrors = require('./util/gql-errors')

const hash = Date.now().toString(36)

const JWT_COOKIE_NAME = 'jwt'
const JWT_COOKIE_PARAMS = {
  maxAge: 1000 * 60 * 60 * 24, // 1 day in milliseconds
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
}
const LEARN_COOKIE_PARAMS = {
  ...JWT_COOKIE_PARAMS,
  maxAge: 1000 * 60 * 60, // 1 hour in milliseconds
}

require('express-async-errors')

const app = express()

app.use(bodyParser.urlencoded({ extended: false }))
app.use(cookieParser())

// See https://github.com/reactjs/express-react-views#add-it-to-your-app
app.set('views', path.join(__dirname, '/views'))
app.set('view engine', 'jsx')
app.engine('jsx', require('express-react-views').createEngine())

async function ensureJwt(req, res, next) {
  if (!get(req.cookies, JWT_COOKIE_NAME)) {
    res.cookie(
      JWT_COOKIE_NAME,
      get(await GQL.rootGetAnonToken(req), 'data.getAnonymousToken.jwtToken'),
      JWT_COOKIE_PARAMS
    )
  }
  next()
}

/* eslint-disable max-params */
function handleError(err, req, res, next) {
  // See express-async-errors
  if (err) res.redirect('/server-error')
  next(err)
}
/* eslint-enable */

function getJwt(req) {
  return jwt.decode(get(req.cookies, JWT_COOKIE_NAME))
}

function getRole(req) {
  return get(getJwt(req), 'role')
}

function isUser(req, res, next) {
  if (!['sg_user', 'sg_admin'].includes(getRole(req))) {
    return res.redirect('/log-in')
  }
  return next()
}

function isAnonymous(req, res, next) {
  if (getRole(req) !== 'sg_anonymous') {
    return res.redirect('/dashboard')
  }
  return next()
}

function setResLocals(req, res, next) {
  res.locals.hash = hash
  res.locals.url = req.url
  res.locals.query = req.query
  res.locals.body = req.body
  res.locals.params = req.params
  res.locals.role = getRole(req)
  return next()
}

function clientizeKind(s) {
  return s.toLowerCase().replace(/_/g, '-')
}

function getQueryState(req) {
  return parseInt(req.query.state, 10) || 0
}

function convertBodyToVars(body) {
  const values = {}
  Object.keys(body)
    .map(key => [key, key.replace(/\$/g, '.')])
    .forEach(([key, xpath]) => set(values, xpath, get(body, key)))
  return values
}

app.use(ensureJwt)
app.use(handleError)
app.use(setResLocals)

// /////////////////////////////////////////////////////////////////////////////

const ROOT_PAGES = [
  '', // home
  '/terms',
  '/contact',
  '/sign-up',
  '/log-in',
  '/email',
  '/password',
  '/search-subjects',
  '/create-subject',
  '/create-card',
  '/create-video-card',
  '/create-choice-card',
  '/create-page-card',
  '/create-unscored-embed-card',
]

app.get('/sitemap.txt', async (req, res) => {
  const gqlRes = await GQL.dataSitemap(req)
  const subjects = get(gqlRes, 'data.allSubjects.nodes', []).map(
    ({ entityId }) => `/subjects/${to58(entityId)}`
  )
  const cards = get(gqlRes, 'data.allCards.nodes', []).map(
    ({ entityId, kind }) =>
      `/${get(CARD_KIND, [kind, 'url'])}-cards/${to58(entityId)}`
  )
  const users = get(gqlRes, 'data.allUsers.nodes', []).map(
    ({ id }) => `/users/${to58(id)}`
  )
  const root =
    process.env.NODE_ENV === 'production' ? 'https://sagefy.org' : 'localhost'
  res.set('Content-Type', 'text/plain').send(
    ROOT_PAGES.concat(subjects)
      .concat(cards)
      .concat(users)
      .map(u => `${root}${u}`)
      .join('\n')
  )
}) // Add more public routes as they are available

// TODO change to /:kind-cards/:cardId/learn
app.get('/learn-:kind/:cardId', async (req, res) => {
  const gqlRes = await GQL.learnGetCard(req, {
    cardId: toU(req.params.cardId),
    subjectId: toU(req.cookies.step),
  })
  const card = get(gqlRes, 'data.cardByEntityId')
  if (!card || clientizeKind(card.kind) !== req.params.kind) {
    return res.redirect('/server-error')
  }
  const progress = get(gqlRes, 'data.selectSubjectLearned')
  return res.render(`Learn${get(CARD_KIND, [req.params.kind, 'page'])}Page`, {
    card,
    progress,
  })
})

// TODO change to /:kind-cards/:cardId/learn
app.post('/learn-choice/:cardId', async (req, res) => {
  const gqlRes = await GQL.learnGetCard(req, {
    cardId: toU(req.params.cardId),
    subjectId: toU(req.cookies.step),
  })
  const card = get(gqlRes, 'data.cardByEntityId')
  if (!card || clientizeKind(card.kind) !== 'choice') {
    return res.redirect('/server-error')
  }
  const gqlRes2 = await GQL.learnRespondCard(req, {
    cardId: toU(req.params.cardId),
    response: req.body.choice,
  })
  const progress = get(gqlRes2, 'data.createResponse.response.learned')
  return res.render('LearnChoicePage', { card, progress })
})

app.get('/sign-up', isAnonymous, (req, res) => res.render('SignUpPage'))

app.post('/sign-up', isAnonymous, async (req, res) => {
  const gqlRes = await GQL.rootNewUser(req, req.body)
  const gqlErrors = getGqlErrors(gqlRes)
  if (Object.keys(gqlErrors).length) {
    return res.render('SignUpPage', { gqlErrors })
  }
  return res
    .cookie(
      JWT_COOKIE_NAME,
      get(gqlRes, 'data.signUp.jwtToken'),
      JWT_COOKIE_PARAMS
    )
    .redirect(
      (req.query.redirect && decodeURIComponent(req.query.redirect)) ||
        '/dashboard'
    )
})

app.get('/log-in', isAnonymous, (req, res) => res.render('LogInPage'))

app.post('/log-in', isAnonymous, async (req, res) => {
  const gqlRes = await GQL.rootLogInUser(req, req.body)
  const gqlErrors = getGqlErrors(gqlRes)
  if (Object.keys(gqlErrors).length) {
    return res.render('LogInPage', { gqlErrors })
  }
  return res
    .cookie(
      JWT_COOKIE_NAME,
      get(gqlRes, 'data.logIn.jwtToken'),
      JWT_COOKIE_PARAMS
    )
    .redirect(
      (req.query.redirect && decodeURIComponent(req.query.redirect)) ||
        '/dashboard'
    )
})

app.get('/email', async (req, res) => {
  const state = getQueryState(req)
  return res.render('EmailPage', { state })
})

app.post('/email', async (req, res) => {
  // TODO split into two routes & pages
  if (getQueryState(req) === 2) {
    const gqlRes = await GQL.rootEditEmail(
      {
        cookies: { [JWT_COOKIE_NAME]: req.query.token },
      },
      req.body
    )
    const gqlErrors = getGqlErrors(gqlRes)
    if (Object.keys(gqlErrors).length) {
      return res.render('EmailPage', { gqlErrors, state: 2 })
    }
    return res.redirect('/log-in')
  }
  const gqlRes = await GQL.rootNewEmailToken(req, req.body)
  const gqlErrors = getGqlErrors(gqlRes)
  if (Object.keys(gqlErrors).length) {
    return res.render('EmailPage', { gqlErrors, state: 0 })
  }
  return res.redirect('/email?state=1')
})

app.get('/password', async (req, res) => {
  const state = getQueryState(req)
  return res.render('PasswordPage', { state })
})

app.post('/password', async (req, res) => {
  // TODO split into to routes & pages
  if (getQueryState(req) === 2) {
    const gqlRes = await GQL.rootEditPassword(
      {
        cookies: { [JWT_COOKIE_NAME]: req.query.token },
      },
      req.body
    )
    const gqlErrors = getGqlErrors(gqlRes)
    if (Object.keys(gqlErrors).length) {
      return res.render('PasswordPage', { gqlErrors, state: 2 })
    }
    return res.redirect('/log-in')
  }
  const gqlRes = await GQL.rootNewPasswordToken(req, req.body)
  const gqlErrors = getGqlErrors(gqlRes)
  if (Object.keys(gqlErrors).length) {
    return res.render('PasswordPage', { gqlErrors, state: 0 })
  }
  return res.redirect('/password?state=1')
})

app.get('/settings', isUser, async (req, res) => {
  const gqlRes = await GQL.rootGetCurrentUser(req)
  const body = get(gqlRes, 'data.getCurrentUser')
  return res.render('SettingsPage', { body })
})

app.post('/settings', isUser, async (req, res) => {
  const gqlRes = await GQL.rootEditUser(req, req.body)
  const gqlErrors = getGqlErrors(gqlRes)
  return res.render('SettingsPage', { gqlErrors })
})

app.get('/log-out', isUser, (req, res) =>
  res.clearCookie(JWT_COOKIE_NAME).redirect('/')
)

app.get('/dashboard', isUser, async (req, res) => {
  const gqlRes = await GQL.learnListUsubj(req)
  const subjects = get(gqlRes, 'data.allUserSubjects.nodes', []).map(
    ({ id, subject: { entityId, name, body } }) => ({
      id,
      entityId,
      name,
      body,
    })
  )
  const name = get(gqlRes, 'data.getCurrentUser.name')
  return res.render('DashboardPage', { subjects, name })
})

// TODO change to /subjects/search
app.get('/search-subjects', async (req, res) => {
  const gqlRes = await GQL.learnSearchSubject(req, req.query)
  const subjects = get(gqlRes, 'data.searchSubjects.nodes')
  return res.render('SearchSubjectsPage', { subjects })
})

// TODO change to /subjects/create
app.get('/create-subject', (req, res) => res.render('CreateSubjectPage'))

// TODO change to /subjects/create
app.post('/create-subject', async (req, res) => {
  const gqlRes = await GQL.contributeNewSubject(req, req.body)
  const gqlErrors = getGqlErrors(gqlRes)
  if (Object.keys(gqlErrors).length) {
    return res.render('CreateSubjectPage', { gqlErrors })
  }
  const role = getRole(req)
  const { entityId, name } = get(gqlRes, 'data.newSubject.subjectVersion', {})
  if (role === 'sg_anonymous') {
    return res.redirect(`/search-subjects?q=${name}`)
  }
  await GQL.learnNewUsubj(req, { subjectId: entityId })
  return res.redirect('/dashboard')
})

app.get('/subjects/:subjectId/edit', async (req, res) => {
  const subjGqlRes = await GQL.contributeGetSubject(req, {
    entityId: toU(req.params.subjectId),
  })
  const subject = get(subjGqlRes, 'data.subjectByEntityId')
  if (!subject) return res.redirect('/server-error')
  return res.render('EditSubjectPage', { subject })
})

app.post('/subjects/:subjectId/edit', async (req, res) => {
  const subjGqlRes = await GQL.contributeGetSubject(req, {
    entityId: toU(req.params.subjectId),
  })
  const subject = get(subjGqlRes, 'data.subjectByEntityId')
  if (!subject) return res.redirect('/server-error')
  const editGqlRes = await GQL.contributeEditSubject(req, {
    entityId: toU(req.body.entityId),
    name: req.body.name,
    body: req.body.body,
    before: get(subject, 'beforeSubjects.nodes', []).map(
      ({ entityId }) => entityId
    ), // temporary
    parent: get(subject, 'parentSubjects.nodes', []).map(
      ({ entityId }) => entityId
    ), // temporary
  })
  const gqlErrors = getGqlErrors(editGqlRes)
  if (Object.keys(gqlErrors).length) {
    return res.render('EditSubjectPage', { subject, gqlErrors })
  }
  return res.redirect(`/subjects/${req.params.subjectId}`)
})

// TODO change to /(:kind-)?cards/create
app.get('/create(-:kind)?-card', async (req, res) => {
  if (!req.query.subjectId) res.redirect('/')
  const subjGqlRes = await GQL.contributeGetSubject(req, {
    entityId: toU(req.query.subjectId),
  })
  const subject = get(subjGqlRes, 'data.subjectByEntityId')
  if (!subject) return res.redirect('/server-error')
  return res.render(
    `Create${get(CARD_KIND, [req.params.kind, 'page'], '')}CardPage`,
    { subject }
  )
})

// TODO change to /(:kind-)?cards/create
app.post('/create(-:kind)?-card', async (req, res) => {
  const values = convertBodyToVars(req.body)
  values.subjectId = toU(values.subjectId)
  if (req.body.kind === 'CHOICE') {
    values.data.body = values.name
    values.data.max_options_to_show = parseInt(
      values.data.max_options_to_show,
      10
    )
    values.data.options = fromPairs(
      [0, 1, 2, 3].map(i => [
        uuidv4(),
        {
          ...get(values.data.options, i),
          correct: values.data.correct === i.toString(),
        },
      ])
    )
    delete values.data.correct
  }
  const gqlRes = await GQL.contributeNewCard(req, values)
  const gqlErrors = getGqlErrors(gqlRes)
  if (Object.keys(gqlErrors).length) {
    return res.render(
      `Create${get(CARD_KIND, [req.params.kind, 'page'], '')}CardPage`,
      { gqlErrors }
    )
  }
  // TODO redirect based on how we got to create-card
  return res.redirect(`/next?step=${req.cookies.step}`)
})

// TODO update url?
app.get('/choose-step', async (req, res) => {
  const role = getRole(req)
  const { goal } = req.cookies
  if (!goal)
    return res.redirect(
      role === 'sg_anonymous' ? '/search-subjects' : '/dashboard'
    )
  const subjects = get(
    await GQL.learnChooseSubject(req, { subjectId: toU(goal) }),
    'data.selectSubjectToLearn.nodes'
  )
  if (!subjects || !subjects.length) {
    return res.redirect(
      role === 'sg_anonymous' ? '/search-subjects' : '/dashboard'
    )
  }
  if (subjects.length === 1) {
    return res.redirect(`/next?step=${to58(subjects[0].entityId)}`)
  }
  return res.render('ChooseStepPage', { subjects })
})

/* eslint-disable max-statements */
app.get('/next', async (req, res) => {
  let { goal, step } = req.cookies
  if (req.query.goal) {
    ;({ goal } = req.query)
    res.cookie('goal', goal, LEARN_COOKIE_PARAMS).clearCookie('step')
    step = null
    await GQL.learnNewUsubj(req, { subjectId: toU(goal) })
  }
  if (req.query.step) {
    ;({ step } = req.query)
    res.cookie('step', step, LEARN_COOKIE_PARAMS)
  }
  if (step) {
    const gqlRes = await GQL.learnGetLearned(req, { subjectId: toU(step) })
    if (get(gqlRes, 'data.selectSubjectLearned') >= 0.99) {
      return res.clearCookie('step').redirect('/choose-step')
    }
    const gqlRes2 = await GQL.learnChooseCard(req, { subjectId: toU(step) })
    const card = get(gqlRes2, 'data.selectCardToLearn.card')
    if (!card) return res.redirect(`/create-card?subjectId=${step}`)
    const { kind, entityId } = card
    return res.redirect(`/learn-${clientizeKind(kind)}/${to58(entityId)}`)
  }
  if (goal) return res.redirect('/choose-step')
  return res.redirect(
    getRole(req) === 'sg_anonymous' ? '/search-subjects' : '/dashboard'
  )
}) /* eslint-enable */

app.get('/subjects/:subjectId', async (req, res) => {
  const gqlRes = await GQL.dataGetSubject(req, {
    entityId: toU(req.params.subjectId),
  })
  const subject = get(gqlRes, 'data.subjectByEntityId')
  // -- photos for the twitter feed
  const response = await request({
    uri: `https://www.flickr.com/services/rest`,
    qs: {
      method: 'flickr.photos.search',
      api_key: process.env.FLICKR_API_KEY,
      text: subject.name,
      per_page: 1,
      format: 'json',
      nojsoncallback: 1,
    },
    json: true,
  })
  const { farm, server, id, secret } = get(response, 'photos.photo[0]', {})
  if (id && farm && server && secret) {
    subject.image = `https://farm${farm}.static.flickr.com/${server}/${id}_${secret}.jpg`
  }
  return res.render('SubjectPage', { subject })
})

app.get('/subjects/:subjectId/history', async (req, res) => {
  const gqlRes = await GQL.dataListSubjectVersions(req, {
    entityId: toU(req.params.subjectId),
  })
  const subject = get(gqlRes, 'data.subjectByEntityId')
  const versions = get(gqlRes, 'data.allSubjectVersions.nodes')
  return res.render('SubjectHistoryPage', { subject, versions })
})

app.get('/(:kind-)?cards/:cardId', async (req, res) => {
  const gqlRes = await GQL.dataGetCard(req, {
    cardId: toU(req.params.cardId),
  })
  const card = get(gqlRes, 'data.cardByEntityId')
  return res.render(
    `${get(CARD_KIND, [req.params.kind, 'page'], '')}CardPage`,
    { card }
  )
})

app.get('/users/:userId', async (req, res) => {
  const gqlRes = await GQL.dataGetUser(req, {
    userId: toU(req.params.userId),
  })
  const user = get(gqlRes, 'data.userById')
  return res.render('UserPage', { user })
})

app.get('/subjects/:subjectId/talk', async (req, res) => {
  const gqlRes = await GQL.contributeListPostsSubject(req, {
    entityId: toU(req.params.subjectId),
  })
  const entity = get(gqlRes, 'data.subjectByEntityId')
  const topics = get(gqlRes, 'data.allTopics.nodes')
  return res.render('TalkPage', { entity, topics })
})

app.get('/(:kind-)?cards/:cardId/talk', async (req, res) => {
  const gqlRes = await GQL.contributeListPostsCard(req, {
    entityId: toU(req.params.cardId),
  })
  const entity = get(gqlRes, 'data.cardByEntityId')
  const topics = get(gqlRes, 'data.allTopics.nodes')
  return res.render('TalkPage', { entity, topics })
})

app.post(
  ['/subjects/:subjectId/talk', '/(:kind-)?cards/:cardId/talk'],
  async (req, res) => {
    const gqlRes = await GQL.contributeNewTopic(req, req.body)
    const gqlErrors = getGqlErrors(gqlRes)
    if (Object.keys(gqlErrors).length) {
      return res.redirect('')
    }
    const topicId = to58(get(gqlRes, 'data.createTopic.topic.id'))
    return res.redirect(`?topic-id=${topicId}#topic-${topicId}`)
  }
)

app.post(
  [
    '/subjects/:subjectId/talk/:topicId/post',
    '/(:kind-)?cards/:cardId/talk/:topicId/post',
  ],
  async (req, res) => {
    const gqlRes = await GQL.contributeNewPost(req, req.body)
    const gqlErrors = getGqlErrors(gqlRes)
    if (Object.keys(gqlErrors).length) {
      return res.redirect(`..?topic-id=${req.params.topicId}`)
    }
    return res.redirect(
      `..?topic-id=${req.params.topicId}#post-${to58(
        get(gqlRes, 'data.createPost.post.id')
      )}`
    )
  }
)

app.get('/terms', (req, res) => res.render('TermsPage'))

app.get('/contact', (req, res) => res.render('ContactPage'))

app.get('/', async (req, res) => {
  const gqlRes = await GQL.learnHome(req)
  const subjects = get(gqlRes, 'data.selectPopularSubjects.nodes')
  const whatIs = get(gqlRes, 'data.whatIsSagefy')
  if (whatIs) subjects.unshift(whatIs)
  return res.render('HomePage', { subjects })
})

app.get('/server-error', (req, res) => res.render('ServerErrorPage'))

app.get('*', (req, res) => res.render('NotFoundPage'))

// /////////////////////////////////////////////////////////////////////////////

/* eslint-disable no-console */
if (require.main === module) {
  console.log('Client running on port', process.env.CLIENT_PORT)
  app.listen(process.env.CLIENT_PORT)
}
/* eslint-enable */

module.exports = app
