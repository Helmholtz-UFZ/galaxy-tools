import java.util.*;

class sleepwaste
{  
        public static void main(String args[])
        {
		long start = System.nanoTime();

       char[] values=new char[Integer.valueOf(args[1])*1024*1024];
	   //Vector<Integer> vector = new Vector<Integer>(Integer.valueOf(args[1])*1024*1024);
/*	   for( int i=0; i<Integer.valueOf(args[1]); i++){
		 vector.add(1);
	   }
*/
	   while( (System.nanoTime() - start)/1000000000 <= Integer.valueOf(args[0])  ){
	   	int a = 1;
	   }
//	   Thread.sleep(Integer.valueOf(args[0])*1024*1024);
	   
	   System.out.println("slept for "+(System.nanoTime() - start)/1000000000+" s and wasted "+args[1]+" MB");
	   System.exit(0); 
	}
}
