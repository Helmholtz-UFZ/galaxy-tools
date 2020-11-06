import argparse
import time

parser = argparse.ArgumentParser()
parser.add_argument("time", help="time (s) to waste", type=int)
parser.add_argument("memory", help="memory (MB) to waste", type=int)

args = parser.parse_args()

array = " "*(args.memory*1024*1024)
time.sleep( args.time )

print "slept for {time} s and {memory} MB".format( time = args.time, memory = args.memory )
