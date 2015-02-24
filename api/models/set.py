from modules.model import Model
from modules.validations import is_required, is_language, is_string, \
    is_boolean, is_list, is_entity_list_dict
from modules.util import uniqid
from models.mixins.entity import EntityMixin


class Set(EntityMixin, Model):
    """
    A set is a collection of units and other sets.
    Sets can vary greatly in scale.
    A graph is automatically formed based on the units and sets specified.
    """
    tablename = 'sets'

    """
    The model represents a **version** of a set, not a set itself.
    The `entity_id` attribute is what refers to a particular set.
    The `id` attribute refers to a specific version of the set.
    The `previous_id` attribute refers to the version based off.
    """

    schema = dict(Model.schema.copy(), **{
        'entity_id': {
            'validate': (is_required, is_string,),  # TODO is valid id?
            'default': uniqid
        },
        'previous_id': {
            'validate': (is_string,),  # TODO is valid id?
        },
        'language': {
            'validate': (is_required, is_language,),
            'default': 'en'
        },
        'name': {
            'validate': (is_required, is_string,)
        },
        'body': {
            'validate': (is_required, is_string,)
        },
        'canonical': {
            'validate': (is_boolean,),
            'default': False
        },
        'available': {
            'validate': (is_boolean,),
            'default': True
        },
        'tags': {
            'validate': (is_list,),
            'default': []
        },
        'members': {
            'validate': (is_required, is_entity_list_dict,),
            # TODO is valid ids?
        }
    })

    def validate(self):
        errors = super().validate()
        if not errors:
            errors += self.ensure_no_cycles()
        return errors

    def ensure_no_cycles(self):
        """
        Ensure no require cycles form.
        """
        # TODO
        return []

    # TODO On set canonical, index (or delete) in Elasticsearch with entity_id
