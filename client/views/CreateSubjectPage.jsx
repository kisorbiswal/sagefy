import React from 'react'
import { string, shape } from 'prop-types'
import Layout from './components/Layout'
import Icon from './components/Icon'
import SubjectForm from './components/SubjectForm'

export default function CreateSubjectPage({
  hash,
  role,
  body = {},
  gqlErrors,
}) {
  return (
    <Layout
      hash={hash}
      page="CreateSubjectPage"
      title="Create subject"
      description="Help Sagefy grow by making a new subject! Anyone can make a new subject, no account required."
    >
      <section>
        <h1>
          Let&apos;s make a new subject! <Icon i="subject" s="h1" />
        </h1>
        <SubjectForm role={role} form={body} gqlErrors={gqlErrors} />
      </section>
    </Layout>
  )
}

CreateSubjectPage.propTypes = {
  hash: string.isRequired,
  role: string.isRequired,
  body: shape({}),
  gqlErrors: shape({}),
}

CreateSubjectPage.defaultProps = {
  body: {},
  gqlErrors: {},
}
