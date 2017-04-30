/* eslint-disable no-underscore-dangle */

const {div, h1, form, input, button, a, ul, li} = require('../../modules/tags')
const icon = require('../components/icon.tmpl')
const previewUnitHead = require('../components/preview_unit_head.tmpl')
const previewSetHead = require('../components/preview_set_head.tmpl')

module.exports = function createSetAdd(data) {
    const {searchResults} = data.create
    const inputOpts = {
        type: 'text',
        placeholder: 'Search Unit and Sets',
        name: 'search',
        size: 40
    }

    return div(
        {id: 'create', className: 'page create--set-add'},
        h1('Add an Existing Unit or Set to New Set'),
        a(
            {href: '/create/set/create'},
            icon('back'),
            ' Back to Create Set form'
        ),
        form(
            {className: 'form--horizontal'},
            div(
                {className: 'form-field form-field--search'},
                input(inputOpts)
            ),
            button(
                {type: 'submit'},
                icon('search'),
                ' Search'
            )
        ),
        searchResults && searchResults.length ? ul(
            {className: 'create--set-add__results'},
            searchResults.map(result => li(
                a(
                    {
                        href: '/create/set/create',
                        className: 'create--set-add__add'
                    },
                    icon('create'),
                    ' Add to Set'
                ),
                result._type === 'set' ?
                    previewSetHead({
                        name: result._source.name,
                        body: result._source.body,
                    }) :
                result._type === 'unit' ?
                    previewUnitHead({
                        name: result._source.name,
                        body: result._source.body,
                    }) :
                    null
            ))
        ) : null
    )
}
