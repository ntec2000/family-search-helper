import unittest
from ocr_spatial import reconstruct
HEADER='level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n'
def row(line,top,text):
    return f'5\t1\t1\t1\t{line}\t1\t10\t{top}\t12\t20\t95\t{text}\n'
class Tests(unittest.TestCase):
    def test_spaces_recovered(self):
        self.assertEqual(reconstruct(HEADER+row(1,0,'賢')+row(1,25,'東'))[0][0],'賢東')
    def test_different_lines_not_joined(self):
        self.assertEqual(len(reconstruct(HEADER+row(1,0,'賢')+row(2,25,'東'))),2)
    def test_large_gap_breaks(self):
        self.assertEqual(len(reconstruct(HEADER+row(1,0,'賢')+row(1,200,'東'))),2)
    def test_nonhan_excluded(self):
        self.assertEqual(reconstruct(HEADER+row(1,0,'ABC')),[])
    def test_confidence_not_filter(self):
        self.assertEqual(reconstruct(HEADER+row(1,0,'賢'))[0][0],'賢')
if __name__=='__main__': unittest.main()
