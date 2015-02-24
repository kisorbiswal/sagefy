from models.unit import Unit


def test_entity_id(app, db_conn, units_table):
    """
    Expect a unit to require an entity_id.
    """

    unit, errors = Unit.insert({
        'name': 'Learn this',
        'body': 'Learn how to do this',
    })
    assert len(errors) == 0
    unit['entity_id'] = 'JFKLD1234'
    unit, errors = unit.save()
    assert len(errors) == 0


def test_previous(app, db_conn, units_table):
    """
    Expect a version previous_id to be a string or None.
    """

    unit, errors = Unit.insert({
        'name': 'Learn this',
        'body': 'Learn how to do this',
    })
    assert len(errors) == 0
    unit['previous_id'] = 'AFJkl345'
    unit, errors = unit.save()
    assert len(errors) == 0


def test_language(app, db_conn, units_table):
    """
    Expect a unit to require a language.
    """

    unit, errors = Unit.insert({
        'name': 'Learn this',
        'body': 'Learn how to do this',
    })
    assert len(errors) == 0
    assert unit['language'] == 'en'


def test_name(app, db_conn, units_table):
    """
    Expect a unit to require a name.
    """

    unit, errors = Unit.insert({
        'body': 'Learn how to do this',
    })
    assert len(errors) == 1
    unit['name'] = 'Learn this'
    unit, errors = unit.save()
    assert len(errors) == 0


def test_body(app, db_conn, units_table):
    """
    Expect a unit to require a body.
    """

    unit, errors = Unit.insert({
        'name': 'Learn this',
    })
    assert len(errors) == 1
    unit['body'] = 'Learn how to do this'
    unit, errors = unit.save()
    assert len(errors) == 0


def test_canonical(app, db_conn, units_table):
    """
    Expect a unit canonical to be a boolean.
    """

    unit, errors = Unit.insert({
        'name': 'Learn this',
        'body': 'Learn how to do this',
    })
    assert len(errors) == 0
    assert unit['canonical'] is False
    unit['canonical'] = True
    unit, errors = unit.save()
    assert len(errors) == 0


def test_tags(app, db_conn, units_table):
    """
    Expect a unit to allow tags.
    """

    unit, errors = Unit.insert({
        'name': 'Learn this',
        'body': 'Learn how to do this',
    })
    assert len(errors) == 0
    unit['tags'] = ['A', 'B']
    unit, errors = unit.save()
    assert len(errors) == 0


def test_requires(app, db_conn, units_table):
    """
    Expect a unit to allow requires ids.
    """

    unit, errors = Unit.insert({
        'name': 'Learn this',
        'body': 'Learn how to do this',
    })
    assert len(errors) == 0
    unit['requires_ids'] = ['A']
    unit, errors = unit.save()
    assert len(errors) == 0
