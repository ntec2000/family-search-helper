import json
import threading
import unittest
from http.client import HTTPConnection
from parser_engine import HTTPServer, Handler, ORIGIN, parse_candidates


class ParserTests(unittest.TestCase):
    def test_person_markers_and_generation(self):
        people = parse_candidates("二十一世\n子格字君平 壬辰年生\n女權龜壽\n二十二世 子承烈", "이")
        self.assertEqual([p["generation"] for p in people], ["21", "21", "22"])
        self.assertEqual(people[0]["name_hanja"], "格")
        self.assertEqual(people[0]["birth_death"], "壬辰年生")
        self.assertEqual(people[1]["name_korean"], "이씨")
        self.assertEqual(people[1]["name_hanja"], "")
        self.assertIn("權龜壽", people[1]["details"])
        self.assertTrue(all(p["verified"] is False for p in people))

    def test_unknown_name_is_not_filled_with_sample(self):
        self.assertEqual(parse_candidates("흐린 글자\n子\n女"), [])

    def test_grave_and_spouse_notes_are_not_persons(self):
        self.assertEqual(parse_candidates("子坐午向\n子孫記錄\n女配某氏"), [])
        person = parse_candidates("21世 諱 格 壬辰生 配 趙氏 丁酉卒")[0]
        self.assertEqual(person["birth_death"], "壬辰生")

    def test_given_names_and_spaced_generation(self):
        people = parse_candidates("21 世 諱 格\n男 核\n휘(諱) 昃")
        self.assertEqual([p["name_hanja"] for p in people], ["格", "核", "昃"])

    def test_invalid_surname(self):
        with self.assertRaises(ValueError):
            parse_candidates("子格", "잘못된성씨")
        self.assertEqual(parse_candidates("女權龜壽", "이씨")[0]["name_korean"], "이씨")

    def test_text_import_endpoint_uses_same_parser(self):
        server = HTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.handle_request)
        thread.start()
        try:
            client = HTTPConnection("127.0.0.1", server.server_port, timeout=3)
            client.request("POST", "/parse", json.dumps({"raw": "子格", "surname": "이"}).encode(),
                           {"Host": "127.0.0.1:8765", "Origin": ORIGIN})
            response = client.getresponse()
            self.assertEqual(response.status, 200)
            self.assertEqual(json.loads(response.read())["candidates"][0]["name_hanja"], "格")
            client.close()
        finally:
            thread.join(timeout=4)
            server.server_close()


if __name__ == "__main__":
    unittest.main()
