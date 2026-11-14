import unittest
from ocr_spatial_v5 import reconstruct
H='level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n'
def row(line,top,text,block=1,conf=90):
    return f'5\t1\t{block}\t1\t{line}\t1\t100\t{top}\t20\t20\t{conf}\t{text}\n'
class Tests(unittest.TestCase):
    def test_same_line(self):self.assertEqual(reconstruct(H+row(1,0,'賢')+row(1,24,'東'))[0]['text'],'賢東')
    def test_separate_line(self):self.assertEqual(len(reconstruct(H+row(1,0,'賢')+row(2,24,'東'))),2)
    def test_separate_block(self):self.assertEqual(len(reconstruct(H+row(1,0,'賢')+row(1,24,'東',block=2))),2)
    def test_no_hallucination(self):self.assertEqual(reconstruct(H+row(1,0,'賢束'))[0]['text'],'賢束')
    def test_invalid_conf(self):self.assertEqual(reconstruct(H+row(1,0,'賢',conf=-1)),[])
    def test_nonhan(self):self.assertEqual(reconstruct(H+row(1,0,'ABC')),[])
    def test_order(self):self.assertEqual(reconstruct(H+row(1,24,'東')+row(1,0,'賢'))[0]['text'],'賢東')
    def test_box(self):self.assertEqual(reconstruct(H+row(1,0,'賢'))[0]['box'],[100,0,120,20])
if __name__=='__main__':unittest.main()
