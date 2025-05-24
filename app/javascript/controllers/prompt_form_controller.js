import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["endpointType", "selectedProvider", "selectedModel", 
                    "systemPrompt", "tools", "flowId", "subjectImage", 
                    "backgroundPrompt", "backgroundReference", "lightSourceDirection", 
                    "lightSourceStrength", "foregroundPrompt", "negativePrompt", 
                    "preserveOriginalSubject", "originalBackgroundDepth", 
                    "keepOriginalBackground", "seed", "outputFormat", "action", 
                    "size", "quality", "attachments"]

  static values = {
    modelOptions: Object
  }

  connect() {
    // Store original values first before we modify the dropdowns
    const origEndpointType = this.endpointTypeTarget.value
    const origProvider = this.selectedProviderTarget.value
    const origModel = this.selectedModelTarget.value
    
    console.log("Initial values:", { origEndpointType, origProvider, origModel })
    
    // If editing an existing record with values
    if (origEndpointType) {
      // First set the endpoint type and update the UI
      this.onEndpointTypeChange()
      
      // Now ensure the provider dropdown has the right option and is selected
      if (origProvider) {
        // Make sure the provider option exists and is selected
        const providerOption = Array.from(this.selectedProviderTarget.options)
          .find(opt => opt.value === origProvider)
        
        if (!providerOption) {
          // If the option doesn't exist (which shouldn't happen, but just in case)
          const newOption = new Option(origProvider, origProvider, true, true)
          this.selectedProviderTarget.add(newOption)
        } else {
          // Select the existing option
          this.selectedProviderTarget.value = origProvider
        }
        
        // Now update the model options based on the provider
        this.onSelectedProviderChange()
        
        // Finally, select the original model if it exists
        if (origModel) {
          const modelOption = Array.from(this.selectedModelTarget.options)
            .find(opt => opt.value === origModel)
          
          if (!modelOption) {
            // If the model option doesn't exist, add it
            const newOption = new Option(origModel, origModel, true, true)
            this.selectedModelTarget.add(newOption)
          } else {
            // Select the existing option
            this.selectedModelTarget.value = origModel
          }
        }
      }
      
      // Show the appropriate fields based on the endpoint type
      if (origEndpointType === "Chat") {
        this.hideAllFieldsExcept(["endpointType", "selectedProvider", "selectedModel", "systemPrompt", "tools", "flowId", "attachments"])
      } else if (origEndpointType === "ImageToImage") {
        this.hideAllFieldsExcept([
          "endpointType", "selectedProvider", "selectedModel", "action", "systemPrompt",
          "subjectImage", "backgroundPrompt", "backgroundReference", 
          "lightSourceDirection", "lightSourceStrength", "foregroundPrompt", 
          "negativePrompt", "preserveOriginalSubject", "originalBackgroundDepth", 
          "keepOriginalBackground", "seed", "outputFormat", "flowId", "size", "quality", "attachments"
        ])
      }
    } else {
      // If creating a new record, just hide all fields except endpoint type
      this.hideAllFieldsExcept(["endpointType", "attachments"])
    }
  }

  onEndpointTypeChange() {
    const endpointType = this.endpointTypeTarget.value
    
    // Reset provider and model selections while preserving current values if they match the new constraints
    const currentProvider = this.selectedProviderTarget.value
    const currentModel = this.selectedModelTarget.value
    
    // Clear and rebuild provider options
    this.selectedProviderTarget.innerHTML = '<option value="">Select a provider</option>'
    
    if (endpointType === "Chat") {
      // For Chat, offer Anthropic and OpenAI providers
      this.selectedProviderTarget.innerHTML += '<option value="Anthropic">Anthropic</option>'
      this.selectedProviderTarget.innerHTML += '<option value="Openai">OpenAI</option>'
      
      // Restore provider selection if valid
      if (currentProvider === "Anthropic" || currentProvider === "Openai") {
        this.selectedProviderTarget.value = currentProvider
      }
      
      // For Chat, only show system_prompt, tools, flow_id
      // Note: make sure action field is not included in the list
      this.hideAllFieldsExcept(["endpointType", "selectedProvider", "selectedModel", "systemPrompt", "tools", "flowId", "attachments"])
      
    } else if (endpointType === "ImageToImage") {
      // For ImageToImage, only offer Stability provider
      this.selectedProviderTarget.innerHTML += '<option value="Stability">Stability</option>'
      this.selectedProviderTarget.innerHTML += '<option value="Openai">OpenAI</option>'
      
      // Restore provider selection if valid
      if (currentProvider === "Stability" || currentProvider === "Openai") {
        this.selectedProviderTarget.value = currentProvider
      }
      
      // For ImageToImage, show all fields except those specific to Chat
      this.hideAllFieldsExcept([
        "endpointType", "selectedProvider", "selectedModel", "action", "systemPrompt",
        "subjectImage", "backgroundPrompt", "backgroundReference", 
        "lightSourceDirection", "lightSourceStrength", "foregroundPrompt", 
        "negativePrompt", "preserveOriginalSubject", "originalBackgroundDepth", 
        "keepOriginalBackground", "seed", "outputFormat", "flowId", "size", "quality", "attachments"
      ])
    } else {
      // If no selection, just show the endpoint type dropdown
      this.hideAllFieldsExcept(["endpointType", "attachments"])
    }
    
    // Update model options based on the new provider
    this.onSelectedProviderChange()
  }
  
  onSelectedProviderChange() {
    const endpointType = this.endpointTypeTarget.value
    const selectedProvider = this.selectedProviderTarget.value
    const currentModel = this.selectedModelTarget.value
    
    // Reset model selection
    this.selectedModelTarget.innerHTML = '<option value="">Select a model</option>'
    
    if (endpointType && selectedProvider && this.modelOptionsValue) {
      // Fix the endpoint key transformation
      let endpointKey
      if (endpointType === "Chat") {
        endpointKey = "chat"
      } else if (endpointType === "ImageToImage") {
        endpointKey = "image_to_image"
      } else {
        endpointKey = endpointType.toLowerCase()
      }
      
      // Fix the provider key transformation
      let providerKey
      if (selectedProvider === "Anthropic") {
        providerKey = "anthropic"
      } else if (selectedProvider === "Openai") {
        providerKey = "openai"
      } else if (selectedProvider === "Stability") {
        providerKey = "stability"
      } else {
        providerKey = selectedProvider.toLowerCase()
      }
      
      const models = this.modelOptionsValue[endpointKey]?.[providerKey]?.models || []
      
      models.forEach(model => {
        this.selectedModelTarget.innerHTML += `<option value="${model}">${model}</option>`
      })
      
      // Restore model selection if valid
      if (models.includes(currentModel)) {
        this.selectedModelTarget.value = currentModel
      }
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