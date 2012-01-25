/*
 * Copyright 2001-2004 The Apache Software Foundation.
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package samples.stock ;

import org.apache.axis.AxisFault;
import org.apache.axis.client.Call;
import org.apache.axis.client.Service;
import org.apache.axis.encoding.XMLType;
import org.apache.axis.utils.Options;

import javax.xml.namespace.QName;
import javax.xml.rpc.ParameterMode;
import java.net.URL;

/**
 *
 * @author Doug Davis (dug@us.ibm.com.com)
 */
public class GetQuote {
    public  String symbol ;
    
  // helper function; does all the real work
    public float getQuote (String args[]) throws Exception {
      Options opts = new Options( args );

      args = opts.getRemainingArgs();

      if ( args == null ) {
        System.err.println( "Usage: GetQuote <symbol>" );
        System.exit(1);
      }

      symbol = args[0] ;

      // useful option for profiling - perhaps we should remove before
      // shipping?
      String countOption = opts.isValueSet('c');
      int count=1;
      if ( countOption != null) {
          count=Integer.valueOf(countOption).intValue();
          System.out.println("Iterating " + count + " times");
      }

      URL url = new URL(opts.getURL());
      String user = opts.getUser();
      String passwd = opts.getPassword();

      Service  service = new Service();

      Float res = new Float(0.0F);
      for (int i=0; i<count; i++) {
          Call     call    = (Call) service.createCall();

          call.setTargetEndpointAddress( url );
          call.setOperationName( new QName("urn:xmltoday-delayed-quotes", "getQuote") );
          call.addParameter( "symbol", XMLType.XSD_STRING, ParameterMode.IN );
          call.setReturnType( XMLType.XSD_FLOAT );

          // TESTING HACK BY ROBJ
          if (symbol.equals("XXX_noaction")) {
              symbol = "XXX";
          }

          call.setUsername( user );
          call.setPassword( passwd );

          Object ret = call.invoke( new Object[] {symbol} );
          if (ret instanceof String) {
              System.out.println("Received problem response from server: "+ret);
              throw new AxisFault("", (String)ret, null, null);
          }
        res = (Float) ret;
      }

        return res.floatValue();
    }

  public static void main(String args[]) {
    try {
        GetQuote gq = new GetQuote();
        float val = gq.getQuote(args);
        // args array gets side-effected
        System.out.println(gq.symbol + ": " + val);
    }
    catch( Exception e ) {
       e.printStackTrace();
    }
  }
  
  public GetQuote () {
  };

};
