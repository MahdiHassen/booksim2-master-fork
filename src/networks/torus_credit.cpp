// $Id$

/*
 Copyright (c) 2007-2015, Trustees of The Leland Stanford Junior University
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 Redistributions of source code must retain the above copyright notice, this 
 list of conditions and the following disclaimer.
 Redistributions in binary form must reproduce the above copyright notice, this
 list of conditions and the following disclaimer in the documentation and/or
 other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include "torus_credit.hpp"
#include "misc_utils.hpp"
#include "routefunc.hpp"
#include <vector>
#include <sstream>

TorusCredit::TorusCredit( const Configuration &config, const string & name ) :
  Network( config, name )
{
  _ComputeSize( config );
  _Alloc( );
  _BuildNet( config );
}

TorusCredit::~TorusCredit( )
{
}

void TorusCredit::_ComputeSize( const Configuration &config )
{
  _k = config.GetInt( "k" );
  _n = config.GetInt( "n" );
  gK = _k; gN = _n;

  _size = powi( _k, _n );
  _nodes = _size;

  // Unidirectional torus has only one channel per dimension direction
  // Each node has n output channels (one per dimension, forward only)
  // Total channels: n * nodes (no bidirectional channels)
  _channels = _n * _nodes;
}

void TorusCredit::_BuildNet( const Configuration &config )
{
  ostringstream router_name;
  
  cout << "Topology: Unidirectional " << _n << "-D " << _k << "-ary torus" << endl;
  cout << "Nodes: " << _nodes << endl;
  cout << "Channels: " << _channels << endl;

  // Create routers
  for ( int node = 0; node < _nodes; ++node ) {
    router_name << "router";
    for ( int dim = 0; dim < _n; ++dim ) {
      router_name << "_" << ( node / powi( _k, dim ) ) % _k;
    }
    
    _routers[node] = Router::NewRouter( config, this, router_name.str( ), 
				       node, _n, _n );
    _timed_modules.push_back(_routers[node]);
    
    router_name.str("");
  }

  // Create channels - unidirectional only
  for ( int node = 0; node < _nodes; ++node ) {
    for ( int dim = 0; dim < _n; ++dim ) {
      // Only create forward channels (no backward channels)
      int channel = node * _n + dim;
      int dest_node = _ForwardNode( node, dim );
      
      // Connect router output to channel input
      _routers[node]->AddOutputChannel( _chan[channel], _chan_cred[channel] );
      
      // Connect channel output to destination router input  
      _routers[dest_node]->AddInputChannel( _chan[channel], _chan_cred[channel] );
    }
  }
}

int TorusCredit::_ForwardChannel( int node, int dim )
{
  // Return the forward channel index for this node and dimension
  return node * _n + dim;
}

int TorusCredit::_ForwardNode( int node, int dim )
{
  // Get the coordinates of the current node
  vector<int> coord(_n);
  int temp = node;
  for ( int d = 0; d < _n; ++d ) {
    coord[d] = temp % _k;
    temp /= _k;
  }
  
  // Move forward in the specified dimension (wrap around for torus)
  coord[dim] = (coord[dim] + 1) % _k;
  
  // Convert coordinates back to node index
  int dest = 0;
  int multiplier = 1;
  for ( int d = 0; d < _n; ++d ) {
    dest += coord[d] * multiplier;
    multiplier *= _k;
  }
  
  return dest;
}

double TorusCredit::Capacity( ) const
{
  // Each node has _n output channels
  return (double)_n / (double)_nodes;
}

void TorusCredit::InsertRandomFaults( const Configuration &config )
{
  // Random fault insertion for testing
  // This is a placeholder - implement as needed
}

// Static function to register routing functions
void TorusCredit::RegisterRoutingFunctions() 
{
  // Register routing functions specific to unidirectional torus
  // We'll reuse the existing torus routing functions but with torus_credit suffix
  gRoutingFunctionMap["dim_order_torus_torus_credit"] = gRoutingFunctionMap["dim_order_torus"];
  gRoutingFunctionMap["dim_order_ni_torus_torus_credit"] = gRoutingFunctionMap["dim_order_ni_torus"];
  gRoutingFunctionMap["dim_order_bal_torus_torus_credit"] = gRoutingFunctionMap["dim_order_bal_torus"];
  gRoutingFunctionMap["min_adapt_torus_torus_credit"] = gRoutingFunctionMap["min_adapt_torus"];
  gRoutingFunctionMap["valiant_torus_torus_credit"] = gRoutingFunctionMap["valiant_torus"];
  gRoutingFunctionMap["valiant_ni_torus_torus_credit"] = gRoutingFunctionMap["valiant_ni_torus"];
  gRoutingFunctionMap["chaos_torus_torus_credit"] = gRoutingFunctionMap["chaos_torus"];
}
