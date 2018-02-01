import logging
import sys
import xml.etree.ElementTree

def process_toolxml( toolxml, tools, edges ):
    e = xml.etree.ElementTree.parse(toolxml).getroot()
    if e.tag != "tool":
        logging.warn("%s: seems to be no tool xml file"%toolxml)
        return
    idee = e.attrib["id"]
    
    tools.add(idee)
    
    inputs = e.find("inputs")
    if inputs == None:
        logging.error("%s: no inputs found"%toolxml)
    else:
        for p in inputs.iterfind("param"):
            if not "type" in p.attrib or p.attrib["type"]!="data":
                continue
            if not "format" in p.attrib:
                continue
            for f in p.attrib["format"].split(","):
                edges.add( "%s -> %s;" %(f, idee ))
    outputs = e.find("outputs")
    if outputs == None:
        logging.error("%s: no outputs found"%toolxml)
    else:
        for p in inputs.iterfind("param"):
            if not "format" in p.attrib:
                continue
            for f in p.attrib["format"].split(","):
                edges.add( "%s -> %s;" %(idee, f ))
tools = set()
edges = set()
for i in range(1, len(sys.argv)):
    process_toolxml( sys.argv[i], tools, edges )

tools = [ "%s [shape=box];"%x for x in tools ]
print """
digraph G {{
{tools}
{edges}
}}""".format(tools = "\n".join(tools), edges = "\n".join(edges))

# TODO 
# - mark optional input
