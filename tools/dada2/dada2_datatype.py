# -*- coding: utf-8 -*-
"""
dada2 datatypes

Author: m.bernt@ufz.de
"""

import logging
import os,os.path,re
from galaxy.datatypes.data import *
from galaxy.datatypes.sniff import *
from galaxy.datatypes.tabular import *

log = logging.getLogger(__name__)


class dada_derep( Tabular ):
    file_ext = "dada2.derep"
    composite_type = 'basic'
    allow_datatype_change = False
    blurb = "dereplicated sequences"

    def __init__(self, **kwd):
        """Initialize derep datatype"""
        super(dada_derep, self).__init__(**kwd)
        self.add_composite_file( 'Rdata', is_binary = True, optional = False )
        self.column_names = ['unique sequence', 'abundance']

class dada_dada( Tabular ):
    file_ext = "dada2.dada"
    blurb = "result of dada"

    def __init__(self, **kwd):
        """Initialize derep datatype"""
        super(dada_dada, self).__init__(**kwd)
        self.add_composite_file( 'Rdata', is_binary = True, optional = False )
        self.column_names = ['sequence', 'abundance', 'n0', 'n1', 'nunq', 'pval', 'birth_type', 'birth_pval', 'birth_fold', 'birth_ham', 'birth_qave']

class dada_errorrates( Tabular ):
    file_ext = "dada2.errorrates"
    blurb = "learned error rates"
    def __init__(self, **kwd):
        """Initialize derep datatype"""
        super(dada_errorrates, self).__init__(**kwd)
        self.add_composite_file( 'Rdata', is_binary = True, optional = False )
        self.column_names = ['transition'] + [ str(_) for _ in range(0,41) ]

class dada_mergepairs( Tabular ):
    file_ext = "dada2.mergepairs"
    blurb = "merged reads"
    def __init__(self, **kwd):
        """Initialize derep datatype"""
        super(dada_mergepairs, self).__init__(**kwd)
        self.column_names = ['abundance', 'sequence', 'forward', 'reverse', 'nmatch', 'nmismatch', 'nindel', 'prefer', 'accept']

class dada_sequencetable( Tabular ):
    file_ext = "dada2.sequencetable"
    blurb = "merged reads"



