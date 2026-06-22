const NodeEditorHooks = {
  DraggableNode: {
    mounted() {
      this.el.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('node-type', this.el.dataset.type);
      });
    }
  },

  NodeDraggable: {
    mounted() {
      // Add hover effects
      this.setupHoverEffects();
      
      // Handle node selection
      this.handleNodeSelection();
      
      // Dragging is now handled completely by NodeCanvas.handleNodeMouseDown
      // to resolve double-firing and conflicting drag events.
    },
    
    handleNodeSelection() {
      this.handleEvent("node_selected", ({ node_id }) => {
        if (this.el.dataset.nodeId === node_id) {
          const nodeBody = this.el.querySelector('.node-body');
          if (nodeBody) nodeBody.setAttribute('filter', 'url(#glow-selected)');
        } else {
          const nodeBody = this.el.querySelector('.node-body');
          if (nodeBody) nodeBody.removeAttribute('filter');
        }
      });
      
      this.handleEvent("canvas_clicked", () => {
        const nodeBody = this.el.querySelector('.node-body');
        if (nodeBody) nodeBody.removeAttribute('filter');
      });
    },
    
    setupHoverEffects() {
      const nodeBody = this.el.querySelector('.node-body');
      
      this.el.addEventListener('mouseenter', () => {
        if (!this.el.classList.contains('selected')) {
          if (nodeBody) nodeBody.setAttribute('filter', 'url(#glow-hover)');
        }
      });
      
      this.el.addEventListener('mouseleave', () => {
        if (!this.el.classList.contains('selected')) {
          if (nodeBody) nodeBody.removeAttribute('filter');
        } else {
          if (nodeBody) nodeBody.setAttribute('filter', 'url(#glow-selected)');
        }
      });
    }
  },

  NodeCanvas: {
    mounted() {
      this.isDragging = false;
      this.draggedNode = null;
      this.isDrawingEdge = false;
      this.startPort = null;
      this.mousePosition = { x: 0, y: 0 };
      this.dragStartPosition = { x: 0, y: 0 };
      this.selectedNodeId = null;
      this.edgeUpdateScheduled = false;

      this.svg = this.el.querySelector('svg');

      this.el.addEventListener('dragover', this.handleDragOver.bind(this));
      this.el.addEventListener('drop', this.handleDrop.bind(this));
      this.el.addEventListener('mousemove', this.handleMouseMove.bind(this));

      this.el.addEventListener('mousedown', this.handleNodeMouseDown.bind(this));
      document.addEventListener('mousemove', this.handleNodeDrag.bind(this));
      document.addEventListener('mouseup', this.handleNodeMouseUp.bind(this));
      document.addEventListener('keydown', this.handleKeyDown.bind(this));
      
      this.setupPortListeners();
      
      setTimeout(() => this.updateEdgePaths(), 100);
      this.setupMutationObserver();
      
      this.handleEvent("node_selected", ({ node_id }) => {
        console.log("Node selected:", node_id);
        this.selectedNodeId = node_id;
        
        document.querySelectorAll('.node').forEach(node => {
          if (node.dataset.nodeId === node_id) {
            node.classList.add('selected');
          } else {
            node.classList.remove('selected');
          }
        });
        
        this.scheduleEdgePathUpdate();
      });
      
      this.handleEvent("canvas_clicked", () => {
        console.log("Canvas clicked, deselecting node");
        this.selectedNodeId = null;
        
        document.querySelectorAll('.node').forEach(node => {
          node.classList.remove('selected');
        });
        
        this.scheduleEdgePathUpdate();
      });
      
      this.handleEvent("edge_completed", () => {
        console.log("Edge completed event received");
        this.scheduleEdgePathUpdate(50);
      });
      
      this.handleEvent("edge_created", ({ edge }) => {
        console.log("Edge created event received:", edge);
        this.scheduleEdgePathUpdate(100);
      });

      this.handleEvent("edge_selected", ({ edge_id }) => {
        console.log("Edge selected:", edge_id);
        document.querySelectorAll('.edge-path').forEach(edge => {
          if (edge.dataset.edgeId === edge_id) {
            edge.classList.add('selected-edge');
            edge.setAttribute('stroke', '#3b82f6');
            edge.setAttribute('stroke-width', '3');
          } else {
            edge.classList.remove('selected-edge');
            edge.setAttribute('stroke', '#666');
            edge.setAttribute('stroke-width', '2');
          }
        });
      });

      this.handleEvent("edge_removed", ({ edge_id }) => {
        console.log("Edge removed event received:", edge_id);
        this.scheduleEdgePathUpdate(50);
      });
      
      this.handleEvent("node_added", () => {
        console.log("Node added event received");
        this.scheduleEdgePathUpdate(100);
      });
      
      this.handleEvent("node_removed", () => {
        console.log("Node removed event received");
        this.scheduleEdgePathUpdate(100);
      });
      
      this.handleEvent("node_updated", () => {
        console.log("Node updated event received");
        this.scheduleEdgePathUpdate(100);
      });
    },

    destroyed() {
      if (this.mutationObserver) {
        this.mutationObserver.disconnect();
      }
    },
    
    setupMutationObserver() {
      this.mutationObserver = new MutationObserver((mutations) => {
        let shouldUpdateEdges = false;
        
        for (const mutation of mutations) {
          if (mutation.type === 'childList') {
            const addedNodes = Array.from(mutation.addedNodes);
            const removedNodes = Array.from(mutation.removedNodes);
            
            const relevantNodeAdded = addedNodes.some(node => 
              node.classList && (node.classList.contains('node') || node.classList.contains('edge'))
            );
            
            const relevantNodeRemoved = removedNodes.some(node => 
              node.classList && (node.classList.contains('node') || node.classList.contains('edge'))
            );
            
            if (relevantNodeAdded || relevantNodeRemoved) {
              shouldUpdateEdges = true;
              break;
            }
          } else if (mutation.type === 'attributes') {
            if (mutation.attributeName === 'transform' && 
                mutation.target.classList && 
                mutation.target.classList.contains('node')) {
              shouldUpdateEdges = true;
              break;
            }
          }
        }
        
        if (shouldUpdateEdges) {
          this.scheduleEdgePathUpdate(50);
        }
      });
      
      this.mutationObserver.observe(this.svg, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['transform', 'data-node-id', 'data-edge-id']
      });
    },
    
    scheduleEdgePathUpdate(delay = 0) {
      if (delay === 0) {
        this.updateEdgePaths();
        return;
      }

      if (this.edgeUpdateScheduled) return;
      this.edgeUpdateScheduled = true;
      
      setTimeout(() => {
        this.updateEdgePaths();
        this.edgeUpdateScheduled = false;
      }, delay);
    },

    handleDragOver(e) {
      e.preventDefault();
      e.dataTransfer.dropEffect = 'move';
    },

    handleDrop(e) {
      e.preventDefault();
      const nodeType = e.dataTransfer.getData('node-type');
      if (!nodeType) return;

      const svgRect = this.svg.getBoundingClientRect();
      const x = e.clientX - svgRect.left;
      const y = e.clientY - svgRect.top;

      const nodeId = `${nodeType}-${Date.now()}`;

      this.pushEvent('node_added', {
        node: {
          id: nodeId,
          type: nodeType,
          position: { x, y },
          data: this.getInitialNodeData(nodeType)
        }
      });
      
      this.scheduleEdgePathUpdate(100);
    },

    handleMouseMove(e) {
      const svgRect = this.svg.getBoundingClientRect();
      this.mousePosition = {
        x: e.clientX - svgRect.left,
        y: e.clientY - svgRect.top
      };

      if (this.isDrawingEdge) {
        this.updateDrawingEdge();
      }
    },

    handleNodeMouseDown(e) {
      if (e.target.closest('.port')) return;
      
      const node = e.target.closest('.node');
      if (!node || e.button !== 0) return;

      this.isDragging = true;
      this.draggedNode = node;
      
      const svgRect = this.svg.getBoundingClientRect();
      this.dragStartPosition = {
        x: e.clientX - svgRect.left,
        y: e.clientY - svgRect.top
      };

      this.pushEvent('mousedown', {
        button: 0,
        clientX: this.dragStartPosition.x,
        clientY: this.dragStartPosition.y,
        node_id: node.dataset.nodeId
      });

      e.preventDefault();
    },

    handleNodeDrag(e) {
      if (!this.isDragging || !this.draggedNode) return;

      const svgRect = this.svg.getBoundingClientRect();
      const currentX = e.clientX - svgRect.left;
      const currentY = e.clientY - svgRect.top;

      const movementX = currentX - this.dragStartPosition.x;
      const movementY = currentY - this.dragStartPosition.y;

      this.pushEvent('mousemove', {
        clientX: currentX,
        clientY: currentY,
        movementX: movementX,
        movementY: movementY
      });

      this.scheduleEdgePathUpdate(0);
      e.preventDefault();
    },

    handleNodeMouseUp(e) {
      if (!this.isDragging) return;

      this.isDragging = false;
      this.draggedNode = null;
      this.dragStartPosition = { x: 0, y: 0 };

      this.pushEvent('mouseup', {});
      this.scheduleEdgePathUpdate(50);
      e.preventDefault();
    },

    handleKeyDown(e) {
      if (e.key === 'Escape' && this.isDragging) {
        this.pushEvent('keydown', { key: 'Escape' });
        this.isDragging = false;
        this.draggedNode = null;
        this.dragStartPosition = { x: 0, y: 0 };
        this.scheduleEdgePathUpdate(50);
      }
    },

    setupPortListeners() {
      this.el.addEventListener('mousedown', (e) => {
        const port = e.target.closest('.port');
        if (!port) return;

        const node = port.closest('.node');
        if (!node) return;

        e.stopPropagation();
        
        const nodeTransform = node.getAttribute('transform');
        const nodePos = this.parseTransform(nodeTransform);
        
        const portCx = parseFloat(port.getAttribute('cx'));
        const portCy = parseFloat(port.getAttribute('cy'));
        const portX = nodePos.x + portCx;
        const portY = nodePos.y + portCy;

        this.isDrawingEdge = true;
        this.startPort = {
          nodeId: node.dataset.nodeId,
          isOutput: port.classList.contains('output'),
          x: portX,
          y: portY
        };

        this.pushEvent('edge_started', {
          source_id: this.startPort.nodeId
        });
      });

      this.el.addEventListener('mouseup', (e) => {
        if (!this.isDrawingEdge) return;

        const port = e.target.closest('.port');
        let completed = false;
        
        if (port) {
          e.stopPropagation();
          const node = port.closest('.node');
          
          if (node) {
            const endNodeId = node.dataset.nodeId;
            const isInput = port.classList.contains('input');

            if (this.startPort.isOutput && isInput) {
              this.pushEvent('edge_completed', {
                target_id: endNodeId
              });
              completed = true;
              this.scheduleEdgePathUpdate(100);
            }
          }
        }

        this.isDrawingEdge = false;
        this.startPort = null;

        if (!completed) {
          this.pushEvent('edge_cancelled', {});
        }
        
        this.scheduleEdgePathUpdate(50);
      });
      
      this.setupPortHoverEffects();
    },
    
    setupPortHoverEffects() {
      this.el.addEventListener('mouseover', (e) => {
        const port = e.target.closest('.port');
        if (port) {
          port.setAttribute('filter', 'url(#port-glow)');
          port.setAttribute('r', '6');
        }
      });
      
      this.el.addEventListener('mouseout', (e) => {
        const port = e.target.closest('.port');
        if (port) {
          port.removeAttribute('filter');
          port.setAttribute('r', '5');
        }
      });
    },

    updateDrawingEdge() {
      if (!this.isDrawingEdge || !this.startPort) return;

      const drawingEdge = this.el.querySelector('#drawing-edge');
      if (!drawingEdge) return;

      const startX = this.startPort.x;
      const startY = this.startPort.y;
      
      const path = `M ${startX} ${startY} 
                    C ${startX + 50} ${startY},
                      ${this.mousePosition.x - 50} ${this.mousePosition.y},
                      ${this.mousePosition.x} ${this.mousePosition.y}`;

      drawingEdge.setAttribute('d', path);
    },

    updateEdgePaths() {
      const edges = this.el.querySelectorAll('.edge-path');
      
      if (edges.length === 0) return;
      
      let updatedCount = 0;
      let errorCount = 0;
      
      edges.forEach(edge => {
        try {
          const sourceId = edge.dataset.source;
          const targetId = edge.dataset.target;
          
          if (!sourceId || !targetId) {
            errorCount++;
            return;
          }
          
          const sourceNode = this.el.querySelector(`[data-node-id="${sourceId}"]`);
          const targetNode = this.el.querySelector(`[data-node-id="${targetId}"]`);
          
          if (!sourceNode || !targetNode) {
            errorCount++;
            return;
          }
          
          const path = this.calculateEdgePath(
            { nodeId: sourceId },
            { nodeId: targetId },
            true
          );
          
          edge.setAttribute('d', path);
          updatedCount++;
        } catch (error) {
          errorCount++;
        }
      });
      
      if (errorCount > 0 && updatedCount > 0) {
        setTimeout(() => this.updateEdgePaths(), 200);
      }
    },

    calculateEdgePath(start, end, isOutput) {
      try {
        const sourceNode = this.el.querySelector(`[data-node-id="${start.nodeId || start.x}"]`);
        const targetNode = this.el.querySelector(`[data-node-id="${end.nodeId || end.x}"]`);
        
        let startX, startY, endX, endY;
        
        if (sourceNode && targetNode) {
          const sourcePos = this.parseTransform(sourceNode.getAttribute('transform'));
          const targetPos = this.parseTransform(targetNode.getAttribute('transform'));
          
          startX = sourcePos.x + 200;
          startY = sourcePos.y + 50;
          endX = targetPos.x;
          endY = targetPos.y + 50;
        } else {
          startX = start.x;
          startY = start.y;
          endX = end.x;
          endY = end.y;
        }
  
        const dx = Math.abs(endX - startX);
        const controlOffset = Math.min(dx * 0.5, 150);
  
        return `M ${startX} ${startY} 
                C ${startX + controlOffset} ${startY},
                  ${endX - controlOffset} ${endY},
                  ${endX} ${endY}`;
      } catch (error) {
        console.error('Error calculating edge path:', error);
        return 'M 0 0 L 0 0';
      }
    },

    parseTransform(transform) {
      if (!transform) return { x: 0, y: 0 };
      const match = transform.match(/translate\(([^,]+),([^)]+)\)/);
      if (!match) return { x: 0, y: 0 };
      return {
        x: parseFloat(match[1]),
        y: parseFloat(match[2])
      };
    },

    getInitialNodeData(type) {
      switch (type) {
        case 'agent':
          return {
            label: 'New Agent',
            description: 'Agent description',
            goal: 'Agent goal',
            components: []
          };
        case 'prism':
          return {
            label: 'New Prism',
            description: 'Prism description',
            input_schema: null,
            output_schema: null
          };
        case 'lens':
          return {
            label: 'New Lens',
            description: 'Lens description',
            url: '',
            method: 'GET',
            schema: null
          };
        case 'beam':
          return {
            label: 'New Beam',
            description: 'Beam description',
            input_schema: null,
            output_schema: null
          };
        default:
          return { label: 'New Node' };
      }
    }
  }
};

export default NodeEditorHooks;