import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "flowId", 
    "message", 
    "inputImageUrl", 
    "subjectImage", 
    "subjectVideo", 
    "backgroundReference"
  ]

  connect() {
    // Check if flow_id is already selected
    if (this.flowIdTarget.value) {
      this.fetchPromptEndpointType()
    }
    
    this.hideAllFieldsExcept(["flowId", "message", "inputImageUrl", "subjectImage"])
  }

  onFlowChange() {
    if (this.flowIdTarget.value) {
      this.fetchPromptEndpointType()
    } else {
      // If no flow is selected, hide all fields except the basic ones
      this.hideAllFieldsExcept(["flowId", "message", "inputImageUrl", "subjectImage"])
    }
  }

  fetchPromptEndpointType() {
    const flowId = this.flowIdTarget.value
    
    // Fetch the prompts for this flow to determine the endpoint type
    fetch(`/flows/${flowId}.json`)
      .then(response => response.json())
      .then(data => {
        // Determine the endpoint type based on the flow's prompts
        this.updateVisibleFields(data)
      })
      .catch(error => {
        console.error("Error fetching flow information:", error)
      })
  }
  
  updateVisibleFields(flowData) {
    if (!flowData.prompts || flowData.prompts.length === 0) {
      // If there are no prompts, show default fields
      this.hideAllFieldsExcept(["flowId", "message", "inputImageUrl", "subjectImage"])
      return
    }
    
    // Check if any prompt has ImageToImage endpoint type
    const hasImageToImage = flowData.prompts.some(
      prompt => prompt.endpoint_type === "ImageToImage"
    )
    
    if (hasImageToImage) {
      // Show fields for ImageToImage
      this.hideAllFieldsExcept([
        "flowId", 
        "message", 
        "inputImageUrl", 
        "subjectImage", 
        "subjectVideo", 
        "backgroundReference"
      ])
    } else {
      // Show fields for Chat
      this.hideAllFieldsExcept([
        "flowId", 
        "message", 
        "inputImageUrl", 
        "subjectImage"
      ])
    }
  }
  
  hideAllFieldsExcept(targetNames) {
    // Get all targets
    const allTargets = this.constructor.targets
    
    // For each target
    allTargets.forEach(targetName => {
      try {
        // Get the parent div of the target element
        const targetElement = this[`${targetName}Target`]
        if (!targetElement) return
        
        // Skip flowId as it might be hidden
        if (targetName === "flowId") return
        
        const parentDiv = targetElement.closest(".my-5")
        if (!parentDiv) return
        
        if (targetNames.includes(targetName)) {
          // Show this field
          parentDiv.style.display = ""
        } else {
          // Hide this field
          parentDiv.style.display = "none"
        }
      } catch (e) {
        console.error(`Error hiding/showing ${targetName}:`, e)
      }
    })
  }
} 