import routes.user_subjects
from datetime import datetime


def prep(db_conn):
    subjects_table.insert([{
        'entity_id': 'A1',
        'name': 'A',
        'body': 'Apple',
        'created': datetime.utcnow(),
        'modified': datetime.utcnow(),
        'status': 'accepted',
    }, {
        'entity_id': 'B2',
        'name': 'B',
        'body': 'Banana',
        'created': datetime.utcnow(),
        'modified': datetime.utcnow(),
        'status': 'accepted',
    }, {
        'entity_id': 'C3',
        'name': 'C',
        'body': 'Coconut',
        'created': datetime.utcnow(),
        'modified': datetime.utcnow(),
        'status': 'accepted',
    }, {
        'entity_id': 'D4',
        'name': 'D',
        'body': 'Date',
        'created': datetime.utcnow(),
        'modified': datetime.utcnow(),
        'status': 'accepted',
    }]).run(db_conn)
    users_subjects_table.insert({
        'user_id': 'abcd1234',
        'subject_ids': [
            'A1',
            'C3',
        ],
        'created': datetime.utcnow(),
        'modified': datetime.utcnow(),
    }).run(db_conn)


def test_get_user_subjects(db_conn, session):

    """
    Expect to get a list of the user's subjects.
    """

    prep(db_conn)
    request = {
        'cookies': {'session_id': session},
        'params': {},
        'db_conn': db_conn,
    }
    code, response = routes.user_subjects.get_user_subjects_route(
        request, 'abcd1234')
    assert code == 200
    assert len(response['subjects']) == 2
    assert response['subjects'][0]['body'] in ('Apple', 'Coconut')


def test_get_user_subjects_401(db_conn):
    """
    Expect get user subjects to 401 when not logged in.
    """

    code, response = routes.user_subjects.get_user_subjects_route({
        'db_conn': db_conn
    }, 'abcd1234')
    assert code == 401


def test_get_user_subjects_403(db_conn, session):
    """
    Expect to 403 if trying to get other user's subjects.
    """

    request = {
        'cookies': {'session_id': session},
        'db_conn': db_conn,
    }
    code, response = routes.user_subjects.get_user_subjects_route(
        request, '1234abcd')
    assert code == 403


def test_add_subject(db_conn, session):
    """
    Expect to add a subject to the user's list.
    """

    subjects_table.insert({
        'entity_id': 'A1',
        'name': 'A',
        'body': 'Apple',
        'created': datetime.utcnow(),
        'modified': datetime.utcnow(),
        'status': 'accepted',
    }).run(db_conn)

    request = {
        'cookies': {'session_id': session},
        'db_conn': db_conn
    }
    code, response = routes.user_subjects.add_subject_route(
        request, 'abcd1234', 'A1')
    assert code == 200
    assert 'A1' in response['subjects']


def test_add_subject_401(db_conn):
    """
    Expect to 401 when trying to add a subject but not logged in.
    """

    code, response = routes.user_subjects.add_subject_route({
        'db_conn': db_conn
    }, 'abcd1234', 'A1')
    assert code == 401


def test_add_subject_403(db_conn, session):
    """
    Expect to 403 when attempt to add to another user's subjects.
    """

    request = {
        'cookies': {'session_id': session},
        'db_conn': db_conn,
    }
    code, response = routes.user_subjects.add_subject_route(
        request, '1234dbca', '2')
    assert code == 403


def test_add_subject_404(db_conn, session):
    """
    Expect to 404 if subject not found.
    """

    request = {
        'cookies': {'session_id': session},
        'db_conn': db_conn,
    }
    code, response = routes.user_subjects.add_subject_route(
        request, 'abcd1234', 'Z9')
    assert code == 404


def test_add_subject_already_added(db_conn, session):
    """
    Expect to 400 if already added subject.
    """

    subjects_table.insert({
        'entity_id': 'A1',
        'name': 'A',
        'body': 'Apple',
        'created': datetime.utcnow(),
        'modified': datetime.utcnow(),
        'status': 'accepted',
    }).run(db_conn)

    request = {
        'cookies': {'session_id': session},
        'db_conn': db_conn,
    }
    code, response = routes.user_subjects.add_subject_route(
        request, 'abcd1234', 'A1')
    assert code == 200
    code, response = routes.user_subjects.add_subject_route(
        request, 'abcd1234', 'A1')
    assert code == 400


def test_select_subject_route(db_conn, session):
    """
    Expect to select a subject.
    """

    subjects_table.insert({
        'entity_id': 'A1',
        'name': 'A',
        'body': 'Apple',
        'created': datetime.utcnow(),
        'modified': datetime.utcnow(),
        'status': 'accepted',
    }).run(db_conn)

    request = {
        'cookies': {'session_id': session},
        'db_conn': db_conn,
    }
    code, response = routes.user_subjects.select_subject_route(
        request, 'abcd1234', 'A1')
    assert code == 200
    assert response['next']['path'] == '/s/subjects/A1/tree'


def test_remove_subject(db_conn, session):
    """
    Expect to remove a subject from the user's list.
    """

    subjects_table.insert({
        'entity_id': 'A1',
        'name': 'A',
        'body': 'Apple',
        'created': datetime.utcnow(),
        'modified': datetime.utcnow(),
        'status': 'accepted',
    }).run(db_conn)

    users_subjects_table.insert({
        'user_id': 'abcd1234',
        'subject_ids': ['A1'],
    }).run(db_conn)

    request = {
        'cookies': {'session_id': session},
        'db_conn': db_conn,
    }
    code, response = routes.user_subjects.remove_subject_route(
        request, 'abcd1234', 'A1')
    assert code == 200


def test_remove_subject_401(db_conn):
    """
    Expect to 401 when trying to remove a user subject not logged in.
    """

    request = {
        'db_conn': db_conn,
    }
    code, response = routes.user_subjects.remove_subject_route(
        request, 'abcd1234', 'A1')
    assert code == 401


def test_remove_subject_403(db_conn, session):
    """
    Expect forbidden when trying to remove another user's subject.
    """

    request = {
        'cookies': {'session_id': session},
        'db_conn': db_conn,
    }
    code, response = routes.user_subjects.remove_subject_route(
        request, '1234dcba', '2')
    assert code == 403


def test_remove_subject_404(db_conn, session):
    """
    Expect to not found when trying to delete an unadded subject.
    """

    request = {
        'cookies': {'session_id': session},
        'db_conn': db_conn,
    }
    code, response = routes.user_subjects.remove_subject_route(
        request, 'abcd1234', 'A1')
    assert code == 404
