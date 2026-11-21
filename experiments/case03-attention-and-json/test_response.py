import unittest

from check_response import validate


def response(content, finish="stop", **message):
    return {"choices": [{"finish_reason": finish, "message": {"content": content, **message}}]}


class ResponseTests(unittest.TestCase):
    def test_malformed_incomplete_and_refused_are_not_schema_passes(self):
        for body in [
            response("not json"), response('{"component":"db"}'),
            response('{"component":"db","cause":"oom","extra":1}'),
            response('{"component":"other","cause":"oom"}'),
            response('{"component":"db","cause":12}'),
            response('{"component":"db","cause":"oom"}', finish="length"),
            response(None, refusal="declined"),
        ]:
            with self.subTest(body=body), self.assertRaises(ValueError):
                validate(body)

    def test_valid_shape_can_have_the_wrong_class(self):
        self.assertEqual(validate(response('{"component":"app","cause":"unknown"}'))["component"], "app")
