import unittest
from ocr_spatial_v2 import reconstruct
H='level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n'
def r(x,y,s):return f'5\t1\t1\t1\t1\t1\t{x}\t{y}\t20\t20\t90\t{s}\n'
class Tests(unittest.TestCase):
 def test_vertical_join(self):self.assertEqual(reconstruct(H+r(100,0,'賢')+r(100,24,'東'))[0]['text'],'賢東')
 def test_columns(self):self.assertEqual([a['text'] for a in reconstruct(H+r(100,0,'賢')+r(50,0,'東'))],['賢','東'])
 def test_gap(self):self.assertEqual(len(reconstruct(H+r(100,0,'賢')+r(100,200,'東'))),2)
 def test_nonhan(self):self.assertEqual(reconstruct(H+r(100,0,'ABC')),[])
 def test_invalid(self):self.assertEqual(reconstruct(H+r(100,0,'賢').replace('90','invalid')),[])
 def test_order(self):self.assertEqual([a['text'] for a in reconstruct(H+r(50,0,'東')+r(100,0,'賢'))],['賢','東'])
 def test_hierarchy(self):self.assertEqual(reconstruct(H+'4\t1\t1\t1\t1\t0\t0\t0\t1\t1\t-1\t賢\n'),[])
 def test_punctuation(self):self.assertEqual(reconstruct(H+r(100,0,'賢,東'))[0]['text'],'賢東')
if __name__=='__main__':unittest.main()
