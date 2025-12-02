import ezomero as ez
import sys

from omero.gateway import BlitzGateway

def establish_connection(uuid_key, usr, psw, host, port):
    if uuid_key is not None:
        conn = BlitzGateway(username="", passwd="", host=host, port=port, secure=True)
        conn.connect(sUuid=uuid_key)
    else:
        conn = ez.connect(usr, psw, "", host, port, secure=True)
    if not conn.connect():
        sys.exit("ERROR: Failed to connect to OMERO server")
    return conn
