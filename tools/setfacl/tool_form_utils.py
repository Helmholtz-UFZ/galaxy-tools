import os

def get_directory_list(dir):
    return [(os.path.join(dir, d), os.path.join(dir, d), False) for d in os.listdir(dir) if os.path.isdir(os.path.join(dir, d)) and not d.startswith(".")]

def get_trans(trans, top_level):
    setfacl_data_table = trans.app.tool_data_tables.get('setfacl_directories')
    data_field = setfacl_data_table.get_field(top_level)
    path =  data_field['path']
    try:
        levels = int(data_field['levels'])
    except ValueError:
        levels = 0
    return get_directory_hierarchy(path, levels)

def get_directory_hierarchy(dir, levels=1):
    options = []
    if levels <= 0:
        return options
    subdirs = [os.path.join(dir, d) for d in os.listdir(dir) if os.path.isdir(os.path.join(dir, d)) and not d.startswith(".")]
    for s in subdirs:
        try:
            sub = get_directory_hierarchy(s, levels-1)
        except:
            sub = []
        options.append({"name": s, 'value': s, "selected": False, 'options': sub})
    return options
