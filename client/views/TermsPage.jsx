import React from 'react'
import { string } from 'prop-types'
import Layout from './components/Layout'
import Icon from './components/Icon'

export default function TermsPage({ hash }) {
  return (
    <Layout hash={hash} page="TermsPage" title="Terms and Privacy">
      <header className="my-c">
        <p>
          <a href="/">
            Go back <Icon i="home" /> home
          </a>
        </p>
        <h1>
          Terms &amp; Privacy <Icon i="terms" s="h1" />
        </h1>
      </header>
      <section>
        <h2>General Terms</h2>
        <p>
          If you have questions about these terms, contact Sagefy at{' '}
          <a href="mailto:support@sagefy.org">support@sagefy.org</a>.
        </p>
        <p>By using Sagefy, you agree to these terms.</p>
        <p>If you do not agree to these terms, you must stop using Sagefy.</p>
        <p>This document is effective as of January 25, 2016.</p>
        <p>Sagefy may change this document at any time without notice.</p>
        <p>
          If any part of this document is invalid, that part is separable from
          the rest of the document and the rest of this document remains valid.
        </p>
        <p>
          If Sagefy does not enforce any part of this document, Sagefy does not
          waive the right to enforce any part of this document.
        </p>
        <p>Sagefy’s software is licensed under the Apache 2.0 license.</p>
        <p>
          <a href="http://www.apache.org/licenses/LICENSE-2.0">
            http://www.apache.org/licenses/LICENSE-2.0
          </a>
        </p>
      </section>
      <section>
        <h2>Disclaimers</h2>
        <p>SAGEFY IS PROVIDED AS-IS AND AS-AVAILABLE.</p>
        <p>SAGEFY MAKES NO WARRANTIES.</p>
        <p>
          SAGEFY DOES NOT OFFER WARRANTIES ON MERCHANTABILITY, FITNESS FOR A
          PARTICULAR USE, OR NON-INFRINGEMENT OF INTELLECTUAL PROPERTY.
        </p>
        <p>SAGEFY IS NOT LIABLE FOR ANY DAMAGES COMING FROM USE OF SAGEFY.</p>
      </section>
      <section>
        <h2>Personal Information</h2>
        <p>Sagefy may contact you by your provided email address.</p>
        <p>
          Sagefy provides support in English, via email, but only as available.
        </p>
        <p>
          Sagefy may use cookies to keep you logged in and to personalize the
          service.
        </p>
        <p>
          Sagefy may collect personally identifying information to provide
          services.
        </p>
        <p>Sagefy uses third-party services to provide service.</p>
        <p>
          Sagefy may send personally identifying information to trusted
          third-parties, such as UserVoice.
        </p>
        <p>
          Sagefy does not sell or rent personally identifying information to
          third-parties.
        </p>
        <p>
          Sagefy may share information to law enforcement without notice only a)
          if required by law, b) to defend Sagefy’s rights and property, or c)
          to ensure personal safety or public safety.
        </p>
        <p>
          If Sagefy merges with or is acquired by another organization, data
          will be transferred to that organization.
        </p>
      </section>
      <section>
        <h2>User Accounts</h2>
        <p>You cannot share a single account with multiple people.</p>
        <p>You cannot make or use more than one account.</p>
        <p>
          If you are under the age of thirteen, you must ask a parent or
          guardian before using Sagefy.
        </p>
        <p>
          You are completely responsible for protecting your account, passwords,
          and tokens.
        </p>
        <p>
          Sagefy is not liable for any damages resulting from unauthorized use
          of your account.
        </p>
        <p>
          Sagefy may close accounts, cancel service, and restrict access in
          Sagefy’s own judgement, even without notice or cause.
        </p>
        <p>
          If you or Sagefy closes your account, your personal information will
          be removed, but your contributions will remain on the service.
        </p>
      </section>
      <section>
        <h2>Community</h2>
        <p>
          You cannot use Sagefy to spam, defame, harass, abuse, threaten,
          defraud, or impersonate any person or entity.
        </p>
        <p>
          You cannot use Sagefy to collect information about other users without
          their consent.
        </p>
        <p>You cannot interfere with any other user’s use of Sagefy.</p>
        <p>You cannot use Sagefy for any illegal purpose.</p>
        <p>
          You cannot use Sagefy to distribute any software intended to cause
          damage, such as viruses or malware.
        </p>
      </section>
      <section>
        <h2>Sharing Content</h2>
        <p>
          By providing content to Sagefy, you agree you own the rights to the
          content and the legal ability to provide the content.
        </p>
        <p>
          By providing content to Sagefy, you agree Sagefy may use this content.
        </p>
        <p>
          By providing content to Sagefy, you confirm that the content is
          licensed under a Creative Commons license or similar license.
        </p>
        <p>
          <a href="http://creativecommons.org/">http://creativecommons.org/</a>
        </p>
        <p>Sagefy does not claim property rights to user-provided content.</p>
        <p>
          Sagefy does not monitor or take responsibility for user contributed
          content.
        </p>
        <p>
          Sagefy, and its content, does not offer professional, financial,
          legal, or medical advice.
        </p>
        <p>
          Sagefy does not warrant any user submitted content is safe, secure,
          truthful, accurate, error-free, correctly categorized, or socially
          acceptable.
        </p>
        <p>No compensation will be given for user-provided content.</p>
        <p>
          Sagefy may update and remove user-provided content, but Sagefy does
          not make any commitment to update or remove content.
        </p>
        <p>
          Sagefy is not responsible for content or agreements on external
          websites, even if Sagefy links to them.
        </p>
      </section>
      <section>
        <h2>Security</h2>
        <p>You cannot interfere with security features of Sagefy.</p>
        <p>
          You cannot use any sort of automated means, such as bots or scrapers,
          to access Sagefy.
        </p>
        <p>You cannot bypass measures to restrict access to Sagefy.</p>
        <p>You cannot disrupt the services with excessive requests.</p>
        <p>
          You cannot gain or attempt to gain unauthorized access to Sagefy’s
          non-public data or infrastructure.
        </p>
      </section>
      <section>
        <h2>DMCA</h2>
        <p>
          If your copyright, patent, or trademark has been violated, contact{' '}
          <a href="mailto:support@sagefy.org">support@sagefy.org</a>.
        </p>
        <p>Notices and counter-notices must meet statutory requirements</p>
      </section>
    </Layout>
  )
}

TermsPage.propTypes = {
  hash: string.isRequired,
}
