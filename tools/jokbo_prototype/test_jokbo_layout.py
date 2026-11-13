import unittest
from PIL import Image, ImageDraw
from jokbo_layout import detect_bands


class BandTests(unittest.TestCase):
    def test_rule_bands(self):
        image = Image.new("RGB", (400, 400), "white")
        draw = ImageDraw.Draw(image)
        for y in (25, 140, 270, 375):
            draw.line((28, y, 355, y), fill="gray", width=2)
        bands = detect_bands(image)
        self.assertEqual(len(bands), 3)
        self.assertTrue(100 <= bands[0][1] - bands[0][0] <= 120)

    def test_blank(self):
        self.assertEqual(detect_bands(Image.new("RGB", (400, 400), "white")), [])


if __name__ == "__main__":
    unittest.main()
