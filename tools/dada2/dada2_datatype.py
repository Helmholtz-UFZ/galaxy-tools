# -*- coding: utf-8 -*-
"""
dada2 datatypes

Author: m.bernt@ufz.de
"""

import logging
import os,os.path,re
from galaxy.datatypes.binary import RData
from galaxy.datatypes.tabular import Tabular

log = logging.getLogger(__name__)


class dada_derep( Tabular ):
    """
    datatype for dada2's derep-class

    - table shows the $uniques member of the list
    - additional file contains the Rdata
    """
    file_ext = "dada2_derep"
    composite_type = 'basic'
    allow_datatype_change = False
    blurb = "dereplicated sequences"

    def __init__(self, **kwd):
        """Initialize derep datatype"""
        super(dada_derep, self).__init__(**kwd)
        self.add_composite_file( 'Rdata', is_binary = True, optional = False )
        self.column_names = ['unique sequence', 'abundance']

class dada_dada( RData ):
    """
    datatype for dada2's dada-class

    note: intended to implement this as table + Rdata like the other data types
    problem is that in non-batch mode the dada wrapper uses discover_datasets
    to get the collection elements and there is currently no way to set extra 
    files when doing this.
    """
    file_ext = "dada2_dada"
    blurb = "result of dada"

class dada_errorrates( Tabular ):
    """
    datatype for dada2's result of learnErrors

    - table shows the $err_out member of the list
    - additional file contains the Rdata
    """
    file_ext = "dada2_errorrates"
    composite_type = 'basic'
    blurb = "learned error rates"
    def __init__(self, **kwd):
        """Initialize derep datatype"""
        super(dada_errorrates, self).__init__(**kwd)
        self.add_composite_file( 'Rdata', is_binary = True, optional = False )
        self.column_names = ['transition'] + [ str(_) for _ in range(0,41) ]

class dada_mergepairs( Tabular ):
    """
    datatype for dada2's result of mergePairs (a data frame)

    - the data is stored as table (wo additional Rdata)
    """
    file_ext = "dada2_mergepairs"
    composite_type = 'basic'
    blurb = "merged reads"
    def __init__(self, **kwd):
        """Initialize derep datatype"""
        super(dada_mergepairs, self).__init__(**kwd)
        self.column_names = ['abundance', 'sequence', 'forward', 'reverse', 'nmatch', 'nmismatch', 'nindel', 'prefer', 'accept']

class dada_sequencetable( Tabular ):
    """
    datatype for dada2's result of makeSequencetable (a named integer matrix col=sequences, rows=samples)
    """

    file_ext = "dada2_sequencetable"
    blurb = "merged reads"


class dada_uniques( Tabular ):
    """
    datatype for dada2's result of makeSequencetable (a named integer matrix col=sequences, rows=samples)
    """

    file_ext = "dada2_uniques"
    blurb = "uniques"
